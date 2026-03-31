import Foundation

public struct ParsedPushPayload: Codable, Sendable {
    let callId: UUID
    let handle: String
    
    public init(callId: UUID, handle: String) {
        self.callId = callId
        self.handle = handle
    }
}
