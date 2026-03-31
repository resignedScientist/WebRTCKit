//
//  WebRTCManagerDelegate.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

import Foundation
import CallKit

@MainActor
protocol CallEstablisherDelegate: AnyObject, Sendable {
    
    func callDidEnd(_ callUUID: UUID, reason: CXCallEndedReason)
    
    func callDidStartConnecting(_ callUUID: UUID)
    
    func callDidConnect(_ callUUID: UUID)
}

final class CallEstablisherDelegateImpl: CallEstablisherDelegate {
    
    private let providerDelegate: ProviderDelegate
    
    init(providerDelegate: ProviderDelegate) {
        self.providerDelegate = providerDelegate
    }
    
    func callDidEnd(_ callUUID: UUID, reason: CXCallEndedReason) {
        providerDelegate.reportCallEnded(
            callUUID,
            at: .now,
            with: reason
        )
    }
    
    func callDidStartConnecting(_ callUUID: UUID) {
        providerDelegate.reportOutgoingCallDidStartConnecting(callUUID, at: .now)
    }
    
    func callDidConnect(_ callUUID: UUID) {
        providerDelegate.reportOutgoingCallDidConnect(callUUID, at: .now)
    }
}
