//
//  CallEstablisher.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

import Foundation
import CallKit

@MainActor
protocol CallEstablisher: Sendable {
    
    func answerCall(_ callUUID: UUID)
    
    func startCall(_ callUUID: UUID, handle: String)
    
    func endCall(_ callUUID: UUID)
    
    func setCallMuted(_ isMuted: Bool)
}

final class CallEstablisherImpl: CallEstablisher {
    
    @Inject(\.config) private var config
    @Inject(\.callManager) private var callManager
    @Inject(\.providerDelegate) private var providerDelegate
    
    private let webRTCManager: WebRTCManager
    private let log = Logger(caller: "CallEstablisher", category: .default)
    
    private var currentCallUUID: UUID?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var isReconnecting = false
    
    init(webRTCManager: WebRTCManager) {
        self.webRTCManager = webRTCManager
        webRTCManager.setCallDelegate(self)
    }
    
    func answerCall(_ callUUID: UUID) {
        Task {
            do {
                try await webRTCManager.answerCall()
            } catch {
                log.error("Failed to answer call - \(error)")
                providerDelegate.reportCallEnded(callUUID, at: .now, with: .failed)
            }
        }
    }
    
    func startCall(_ callUUID: UUID, handle: String) {
        Task {
            do {
                try await webRTCManager.startVideoCall(to: handle)
                startConnectionTimeout()
            } catch {
                log.error("Failed to start call - \(error)")
                providerDelegate.reportCallEnded(callUUID, at: .now, with: .failed)
            }
        }
    }
    
    func endCall(_ callUUID: UUID) {
        currentCallUUID = nil
        Task {
            do {
                try await webRTCManager.stopVideoCall()
            } catch {
                log.error("Failed to end call - \(error)")
            }
        }
    }
    
    func setCallMuted(_ isMuted: Bool) {
        webRTCManager.setLocalAudioMuted(isMuted)
    }
}

extension CallEstablisherImpl: WebRTCManagerCallDelegate {
    
    func didReceiveOffer(from peerID: PeerID) {
        Task {
            do {
                let callUUID = UUID()
                try await providerDelegate.reportNewIncomingCall(
                    uuid: callUUID,
                    handle: peerID
                )
                self.currentCallUUID = callUUID
            } catch {
                log.error("Failed to report incoming call - \(error)")
            }
        }
    }
    
    func peerDidAcceptCallRequest() {
        guard let currentCallUUID else { return }
        providerDelegate.reportOutgoingCallDidStartConnecting(
            currentCallUUID,
            at: .now
        )
    }
    
    func callDidStart() {
        guard let currentCallUUID else { return }
        
        if !isReconnecting {
            providerDelegate.reportOutgoingCallDidConnect(
                currentCallUUID,
                at: .now
            )
        }
        
        isReconnecting = false
        cancelConnectionTimeout()
    }
    
    func didReceiveEndCall() {
        guard let currentCallUUID else { return }
        providerDelegate.reportCallEnded(
            currentCallUUID,
            at: .now,
            with: .remoteEnded
        )
        self.currentCallUUID = nil
    }
    
    func didLosePeerConnection() {
        log.info("Did lose peer connection; starting timeout…")
        isReconnecting = true
        startConnectionTimeout()
    }
    
    func shouldConnect(to remotePeerID: PeerID) async {
        do {
            currentCallUUID = try await callManager.requestStartCall(remotePeerID)
        } catch {
            log.error("Failed to request start call - \(error)")
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
            
            guard !Task.isCancelled, let currentCallUUID else { return }
            
            log.error("Connection timeout.")
            
            providerDelegate.reportCallEnded(
                currentCallUUID,
                at: .now,
                with: .failed
            )
            
            self.currentCallUUID = nil
            isReconnecting = false
            
        } catch {
            if !(error is CancellationError) {
                log.error("Error aborting connecting call - \(error)")
            }
        }
    }
}
