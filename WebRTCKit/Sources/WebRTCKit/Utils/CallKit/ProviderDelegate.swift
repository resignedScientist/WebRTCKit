//
//  ProviderHandler.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

import CallKit
import AVFoundation

protocol ProviderDelegate: Sendable {
    
    func reportNewIncomingCall(uuid: UUID, handle: String) async throws
    
    func reportOutgoingCallDidStartConnecting(_ callUUID: UUID, at connectingDate: Date)
    
    func reportOutgoingCallDidConnect(_ callUUID: UUID, at connectedDate: Date)
    
    func reportCallEnded(_ callUUID: UUID, at endDate: Date, with reason: CXCallEndedReason)
}

final class ProviderDelegateImpl: NSObject, ProviderDelegate {
    
    private let callManager: CallManager
    private let audioSessionConfigurator: AudioSessionConfigurator
    private let provider: CXProvider
    
    init(
        callManager: CallManager,
        audioSessionConfigurator: AudioSessionConfigurator
    ) {
        self.callManager = callManager
        self.audioSessionConfigurator = audioSessionConfigurator
        
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.includesCallsInRecents = false
        
        if #available(iOS 26.0, *) {
            configuration.supportsAudioTranslation = false
        }
        
        provider = CXProvider(configuration: configuration)
        
        super.init()
        
        provider.setDelegate(self, queue: .main)
    }
    
    func reportNewIncomingCall(uuid: UUID, handle: String) async throws {
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .generic, value: handle)
        
        try await provider.reportNewIncomingCall(with: uuid, update: callUpdate)
        
        let call = Call(
            uuid: uuid,
            handle: handle,
            direction: .incoming,
            isMuted: false
        )
        
        callManager.addCall(call)
    }
    
    func reportOutgoingCallDidStartConnecting(_ callUUID: UUID, at connectingDate: Date) {
        provider.reportOutgoingCall(
            with: callUUID,
            startedConnectingAt: connectingDate
        )
    }
    
    func reportOutgoingCallDidConnect(_ callUUID: UUID, at connectedDate: Date) {
        provider.reportOutgoingCall(
            with: callUUID,
            connectedAt: connectedDate
        )
    }
    
    func reportCallEnded(_ callUUID: UUID, at endDate: Date, with reason: CXCallEndedReason) {
        provider.reportCall(
            with: callUUID,
            endedAt: endDate,
            reason: reason
        )
    }
}

extension ProviderDelegateImpl: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        audioSessionConfigurator.stopAudio()
        callManager.endAllCalls()
        callManager.removeAllCalls()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        
        let call = Call(
            uuid: action.callUUID,
            handle: action.handle.value,
            direction: .outgoing,
            isMuted: false
        )
        
        audioSessionConfigurator.configureAudioSession()
        
        callManager.addCall(call)
        callManager.startCall(call)
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        
        guard let call = callManager.callWithUUID(action.callUUID) else {
            action.fail()
            return
        }
        
        audioSessionConfigurator.configureAudioSession()
        callManager.answerCall(call)
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        
        guard let call = callManager.callWithUUID(action.callUUID) else {
            action.fail()
            return
        }
        
        callManager.endCall(call)
        callManager.removeCall(call)
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        
        guard let call = callManager.callWithUUID(action.callUUID) else {
            action.fail()
            return
        }
        
        callManager.setCallMuted(call: call, isMuted: action.isMuted)
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioSessionConfigurator.startAudio()
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        audioSessionConfigurator.stopAudio()
    }
}
