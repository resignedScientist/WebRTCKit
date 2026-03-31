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
    
    func setDelegate(_ delegate: CallEstablisherDelegate?)
    
    func answerCall(_ callUUID: UUID)
    
    func startCall(_ callUUID: UUID)
    
    func endCall(_ callUUID: UUID)
    
    func setCallMuted(callUUID: UUID, isMuted: Bool)
}

final class CallEstablisherImpl: CallEstablisher {
    
    @Inject(\.callManager) private var callManager
    @Inject(\.providerDelegate) private var providerDelegate
    
    private let webRTCManager: WebRTCManager
    private let log = Logger(caller: "CallEstablisher", category: .default)
    
    private weak var delegate: CallEstablisherDelegate?
    
    private var currentCallUUID: UUID?
    
    init(webRTCManager: WebRTCManager) {
        self.webRTCManager = webRTCManager
        webRTCManager.setCallDelegate(self)
    }
    
    func setDelegate(_ delegate: CallEstablisherDelegate?) {
        self.delegate = delegate
    }
    
    func answerCall(_ callUUID: UUID) {
        Task {
            do {
                try await webRTCManager.answerCall()
            } catch {
                // TODO: handle error properly with CallKit
                log.error("Failed to answer call - \(error)")
            }
        }
    }
    
    func startCall(_ callUUID: UUID) {
        // TODO: we need the peer id here
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
    
    func setCallMuted(callUUID: UUID, isMuted: Bool) {
        // TODO
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
        providerDelegate.reportOutgoingCallDidConnect(
            currentCallUUID,
            at: .now
        )
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
        // TODO: what to do here? We lost connection and waiting for reconnection
        // Can / should we inform CallKit?
    }
    
    func shouldConnect(to remotePeerID: PeerID) async {
        do {
            try await callManager.requestStartCall(remotePeerID)
        } catch {
            log.error("Failed to request start call - \(error)")
        }
    }
}
