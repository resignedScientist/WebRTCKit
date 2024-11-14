import Foundation

@WebRTCActor
protocol VoIPCallProvider: Sendable {
    
    func reportIncomingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool
    ) async throws
    
    func startOutgoingCall(
        uuid: UUID,
        handle: String,
        hasVideo: Bool
    ) async throws
    
    func acceptIncomingCall() async throws
    
    func endCall() async throws
}
