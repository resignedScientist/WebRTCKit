import Foundation

public enum WebRTCKitCallState: Sendable {
    
    /// Nothing is going on and we are waiting for input.
    case idle
    
    /// A call is running.
    case callIsRunning
    
    /// We are receiving a call request and did not answer yet.
    case receivingCallRequest
    
    /// We are sending a call request and the receiver did not answer yet.
    case sendingCallRequest
    
    /// We are sending an answer to the received call request.
    case answeringCallRequest
    
    /// We are ending a call.
    case endingCall
    
    /// We are trying to establish a peer-to-peer connection.
    case connecting
}

@MainActor
public protocol WebRTCKitCallStateDelegate: AnyObject, Sendable {
    
    func callStateDidChange(to callState: WebRTCKitCallState, call: Call)
    
    func muteStateDidChange(to isMuted: Bool, callUUID: UUID)
}
