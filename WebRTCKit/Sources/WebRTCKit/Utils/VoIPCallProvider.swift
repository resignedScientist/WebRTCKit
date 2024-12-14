import Foundation
import AVKit
import CallKit
import WebRTC

/// The `VoIPCallProvider` protocol defines the essential methods required
/// for handling Voice over IP (VoIP) calls, including reporting incoming calls,
/// starting outgoing calls, accepting calls, and ending calls.
///
/// This is needed to communicate with the system to make it act like a usual call
/// including the call UI the user is used to.
@WebRTCActor
protocol VoIPCallProvider: Sendable {
    
    /// Reports an incoming call to the system, allowing the user to accept or deny the call.
    /// - Parameters:
    ///   - uuid: A unique identifier for the call.
    ///   - handle: The handle (e.g., phone number or contact) associated with the call.
    ///   - hasVideo: A Boolean indicating whether the call includes video.
    /// - Throws: An error if the call cannot be reported.
    func reportIncomingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool
    ) async throws
    
    /// Initiates an outgoing call using the specified parameters.
    /// - Parameters:
    ///   - uuid: A unique identifier for the call.
    ///   - handle: The handle (e.g., phone number or contact) associated with the call.
    ///   - hasVideo: A Boolean indicating whether the call includes video.
    /// - Throws: An error if the call cannot be started.
    func startOutgoingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool
    ) async throws
    
    /// Accepts an incoming call, allowing the user to begin communication.
    /// - Throws: An error if the call cannot be accepted.
    func acceptIncomingCall() async throws
    
    /// Ends an active call, terminating communication.
    /// - Throws: An error if the call cannot be ended.
    func endCall() async throws
}
