//
//  CallEstablisher.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

import Foundation
import CallKit

@MainActor
protocol CallEstablisher {
    
    func setCallStateDelegate(_ callStateDelegate: WebRTCKitCallStateDelegate?)
    
    func answerCall(_ call: Call)
    
    func startCall(_ call: Call)
    
    func endCall(_ call: Call)
    
    func setCallMuted(_ isMuted: Bool, callUUID: UUID)
    
    func setAutoAcceptCalls(autoAccept: Bool)
}

final class CallEstablisherImpl: CallEstablisher {
    
    @Inject(\.config) private var config
    @Inject(\.callManager) private var callManager
    @Inject(\.providerDelegate) private var providerDelegate
    @Inject(\.signalingServer) private var signalingServer
    
    private let webRTCManager: WebRTCManager
    private let log = Logger(caller: "CallEstablisher", category: .default)
    
    private weak var callStateDelegate: WebRTCKitCallStateDelegate?
    
    private var currentCall: Call?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var isReconnecting = false
    private var autoAccept = false
    private var autoAcceptHandle: String?
    
    init(webRTCManager: WebRTCManager) {
        self.webRTCManager = webRTCManager
        webRTCManager.setCallDelegate(self)
    }
    
    func setCallStateDelegate(_ callStateDelegate: WebRTCKitCallStateDelegate?) {
        self.callStateDelegate = callStateDelegate
    }
    
    func answerCall(_ call: Call) {
        
        log.info("answerCall")
        
        currentCall = call
        
        Task {
            do {
                callStateDelegate?.callStateDidChange(to: .answeringCallRequest, call: call)
                
                // we are connecting to the signaling server and wait for a shouldConnect
                try await signalingServer.connect()
            } catch {
                log.error("Failed to answer call - \(error)")
                providerDelegate.reportCallEnded(call.uuid, at: .now, with: .failed)
                callStateDelegate?.callStateDidChange(to: .idle, call: call)
                reset()
            }
        }
    }
    
    func startCall(_ call: Call) {
        
        log.info("startCall")
        
        currentCall = call
        
        if autoAccept, let autoAcceptHandle, autoAcceptHandle == call.handle {
            log.info("Starting call is auto accept call; sending answer…")
            answerCall(call)
            self.autoAcceptHandle = nil
        } else {
            Task {
                do {
                    callStateDelegate?.callStateDidChange(to: .sendingCallRequest, call: call)
                    try await webRTCManager.startVideoCall(to: call.handle)
                    startConnectionTimeout()
                } catch {
                    log.error("Failed to start call - \(error)")
                    providerDelegate.reportCallEnded(call.uuid, at: .now, with: .failed)
                    callStateDelegate?.callStateDidChange(to: .idle, call: call)
                    reset()
                }
            }
        }
    }
    
    func endCall(_ call: Call) {
        log.info("endCall")
        reset()
        Task {
            do {
                callStateDelegate?.callStateDidChange(to: .endingCall, call: call)
                try await webRTCManager.stopVideoCall()
                callStateDelegate?.callStateDidChange(to: .idle, call: call)
            } catch {
                log.error("Failed to end call - \(error)")
                callStateDelegate?.callStateDidChange(to: .idle, call: call)
                reset()
            }
        }
    }
    
    func setCallMuted(_ isMuted: Bool, callUUID: UUID) {
        log.info("setCallMuted - \(isMuted)")
        webRTCManager.setLocalAudioMuted(isMuted)
        callStateDelegate?.muteStateDidChange(to: isMuted, callUUID: callUUID)
    }
    
    func setAutoAcceptCalls(autoAccept: Bool) {
        self.autoAccept = autoAccept
    }
}

extension CallEstablisherImpl: WebRTCManagerCallDelegate {
    
    func didReceiveOffer(from peerID: PeerID) {
        log.info("Did receive offer from \(peerID)")
        if autoAccept {
            Task {
                do {
                    autoAcceptHandle = peerID
                    try await callManager.requestStartCall(peerID)
                } catch {
                    log.error("requesting start call (auto accept) failed - \(error)")
                    reset()
                }
            }
        } else {
            Task {
                do {
                    let call = try await providerDelegate.reportNewIncomingCall(
                        uuid: UUID(),
                        handle: peerID
                    )
                    self.currentCall = call
                    callStateDelegate?.callStateDidChange(to: .receivingCallRequest, call: call)
                } catch {
                    log.error("Failed to report incoming call - \(error)")
                    reset()
                }
            }
        }
    }
    
    func peerDidAcceptCallRequest() {
        guard let currentCall else { return }
        log.info("peerDidAcceptCallRequest")
        providerDelegate.reportOutgoingCallDidStartConnecting(
            currentCall.uuid,
            at: .now
        )
        callStateDelegate?.callStateDidChange(to: .connecting, call: currentCall)
    }
    
    func callDidStart() {
        guard let currentCall else { return }
        
        log.info("callDidStart")
        
        if !isReconnecting {
            providerDelegate.reportOutgoingCallDidConnect(
                currentCall.uuid,
                at: .now
            )
        }
        
        callStateDelegate?.callStateDidChange(to: .callIsRunning, call: currentCall)
        
        isReconnecting = false
        cancelConnectionTimeout()
    }
    
    func didReceiveEndCall() {
        guard let currentCall else { return }
        
        log.info("didReceiveEndCall")
        
        providerDelegate.reportCallEnded(
            currentCall.uuid,
            at: .now,
            with: .remoteEnded
        )
        callStateDelegate?.callStateDidChange(to: .idle, call: currentCall)
        self.currentCall = nil
        autoAcceptHandle = nil
    }
    
    func didLosePeerConnection() {
        guard let currentCall else { return }
        log.info("Did lose peer connection; starting timeout…")
        isReconnecting = true
        startConnectionTimeout()
        callStateDelegate?.callStateDidChange(to: .connecting, call: currentCall)
    }
    
    func shouldConnect(to remotePeerID: PeerID) async {
        log.info("shouldConnect")
        do {
            try await webRTCManager.startVideoCall(to: remotePeerID)
        } catch {
            log.error("shouldConnect failed - \(error)")
            if let currentCall {
                providerDelegate.reportCallEnded(
                    currentCall.uuid,
                    at: .now,
                    with: .failed
                )
            }
            reset()
        }
    }
}

// MARK: - Timeout

private extension CallEstablisherImpl {
    
    func startConnectionTimeout() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { [weak self] in
            await self?.waitForTimeout()
        }
    }
    
    func cancelConnectionTimeout() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
    }
    
    func waitForTimeout() async {
        
        defer {
            cancelConnectionTimeout()
        }
        
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000 * config.connectionTimeout)
            
            guard !Task.isCancelled, let currentCall else { return }
            
            log.error("Connection timeout.")
            
            providerDelegate.reportCallEnded(
                currentCall.uuid,
                at: .now,
                with: .failed
            )
            
            callStateDelegate?.callStateDidChange(to: .idle, call: currentCall)
            
            self.currentCall = nil
            isReconnecting = false
            autoAcceptHandle = nil
            
        } catch {
            if !(error is CancellationError) {
                log.error("Error aborting connecting call - \(error)")
            }
        }
    }
}

// MARK: - Private functions

private extension CallEstablisherImpl {
    
    func reset() {
        log.info("reset")
        currentCall = nil
        autoAcceptHandle = nil
        isReconnecting = false
        cancelConnectionTimeout()
    }
}
