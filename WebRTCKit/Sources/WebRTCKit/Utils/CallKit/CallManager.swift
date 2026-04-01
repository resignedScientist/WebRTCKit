//
//  CallManager.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

import Foundation
import CallKit

@MainActor
protocol CallManager {
    
    /// Sets the delegate to handle call state changes.
    /// - Parameter delegate: A delegate conforming to `WebRTCKitCallStateDelegate`.
    func setCallStateDelegate(_ callStateDelegate: WebRTCKitCallStateDelegate?)
    
    /// Called by the app to request a start call transaction.
    func requestStartCall(_ handle: String) async throws
    
    /// Called by the app to request an end call transaction.
    func requestEndCall(_ call: Call) async throws
    
    /// Called by the app to request end call transactions for all calls.
    func requestEndAllCalls() async throws
    
    /// Called by the app to request a mute / unmute transaction.
    func requestCallMuted(_ call: Call, muted: Bool) async throws
    
    /// Called by the app to request an answer call transaction.
    func requestAcceptIncomingCall(_ call: Call) async throws
    
    /// Called by the provider delegate to add a call to our list.
    func addCall(_ call: Call)
    
    /// Called by the provider delegate to remove a call from our list.
    func removeCall(_ call: Call)
    
    /// Called by the provider delegate to remove all calls from our list.
    func removeAllCalls()
    
    /// Called by the provider delegate or the app to get a call from our list.
    func callWithUUID(_ uuid: UUID) -> Call?
    
    /// Called by the provider delegate when an answer call action has been received.
    func answerCall(_ call: Call)
    
    /// Called by the provider delegate when a start call action has been received.
    func startCall(_ call: Call)
    
    /// Called by the provider delegate when an end call action has been received.
    func endCall(_ call: Call)
    
    /// Called by the provider delegate to end all calls.
    func endAllCalls()
    
    /// Called by the provider delegate to mute / unmute the microphone.
    func setCallMuted(call: Call, isMuted: Bool)
}

final class CallManagerImpl: CallManager {
    
    private let callEstablisher: CallEstablisher
    private let callController = CXCallController(queue: .main)
    
    private var calls: [UUID: Call] = [:]
    
    init(callEstablisher: CallEstablisher) {
        self.callEstablisher = callEstablisher
    }
    
    func setCallStateDelegate(_ callStateDelegate: WebRTCKitCallStateDelegate?) {
        callEstablisher.setCallStateDelegate(callStateDelegate)
    }
    
    func requestStartCall(_ handle: String) async throws {
        
        let callUUID = UUID()
        let cxHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: callUUID, handle: cxHandle)
        
        let transaction = CXTransaction(action: startCallAction)
        
        try await callController.request(transaction)
    }
    
    func requestEndCall(_ call: Call) async throws {
        let endCallAction = CXEndCallAction(call: call.uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        try await callController.request(transaction)
    }
    
    func requestEndAllCalls() async throws {
        for call in calls.values {
            try await requestEndCall(call)
        }
    }
    
    func requestCallMuted(_ call: Call, muted: Bool) async throws {
        let muteCallAction = CXSetMutedCallAction(
            call: call.uuid,
            muted: muted
        )
        let transaction = CXTransaction(action: muteCallAction)
        
        try await callController.request(transaction)
    }
    
    func requestAcceptIncomingCall(_ call: Call) async throws {
        let answerCallAction = CXAnswerCallAction(call: call.uuid)
        let transaction = CXTransaction(action: answerCallAction)
        
        try await callController.request(transaction)
    }
    
    func addCall(_ call: Call) {
        calls[call.uuid] = call
    }
    
    func removeCall(_ call: Call) {
        calls.removeValue(forKey: call.uuid)
    }
    
    func removeAllCalls() {
        calls.removeAll()
    }
    
    func callWithUUID(_ uuid: UUID) -> Call? {
        calls[uuid]
    }
    
    func answerCall(_ call: Call) {
        callEstablisher.answerCall(call)
    }
    
    func startCall(_ call: Call) {
        callEstablisher.startCall(call)
    }
    
    func endCall(_ call: Call) {
        callEstablisher.endCall(call)
    }
    
    func endAllCalls() {
        for call in calls.values {
            endCall(call)
        }
    }
    
    func setCallMuted(call: Call, isMuted: Bool) {
        calls[call.uuid] = call.muted(isMuted)
        callEstablisher.setCallMuted(isMuted, callUUID: call.uuid)
    }
}
