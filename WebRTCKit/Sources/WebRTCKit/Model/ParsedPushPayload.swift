import Foundation

public struct ParsedPushPayload: Codable, Sendable {
    let handle: String
    
    public init(handle: String) {
        self.handle = handle
    }
}
