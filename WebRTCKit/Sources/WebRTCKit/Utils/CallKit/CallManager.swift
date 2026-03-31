//
//  CallManager.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

import Foundation
import CallKit

@MainActor
protocol CallManager: Sendable {
    
    /// Called by the app to request a start call transaction.
    func requestStartCall(_ handle: String) async throws
    
    /// Called by the app to request an end call transaction.
    func requestEndCall(_ call: Call) async throws
    
    /// Called by the provider delegate to add a call to our list.
    func addCall(_ call: Call)
    
    /// Called by the provider delegate to remove a call from our list.
    func removeCall(_ call: Call)
    
    /// Called by the provider delegate to remove all calls from our list.
    func removeAllCalls()
    
    /// Called by the provider delegate to get a call from our list.
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
        callEstablisher.answerCall(call.uuid)
    }
    
    func startCall(_ call: Call) {
        callEstablisher.startCall(call.uuid, handle: call.handle)
    }
    
    func endCall(_ call: Call) {
        callEstablisher.endCall(call.uuid)
    }
    
    func endAllCalls() {
        for call in calls.values {
            endCall(call)
        }
    }
    
    func setCallMuted(call: Call, isMuted: Bool) {
        calls[call.uuid] = call.muted(isMuted)
        callEstablisher.setCallMuted(callUUID: call.uuid, isMuted: isMuted)
    }
}
