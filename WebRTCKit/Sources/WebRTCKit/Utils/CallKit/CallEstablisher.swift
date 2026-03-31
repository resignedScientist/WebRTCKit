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

struct CallEstablisherImpl: CallEstablisher {
    
    private let webRTCManager: WebRTCManager
    
    init(webRTCManager: WebRTCManager) {
        self.webRTCManager = webRTCManager
    }
    
    func setDelegate(_ delegate: CallEstablisherDelegate?) {
        
    }
    
    func answerCall(_ callUUID: UUID) {
        
    }
    
    func startCall(_ callUUID: UUID) {
        
    }
    
    func endCall(_ callUUID: UUID) {
        
    }
    
    func setCallMuted(callUUID: UUID, isMuted: Bool) {
        
    }
}
