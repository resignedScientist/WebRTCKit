import Foundation
import PushKit

public struct PushPayload {
    
    public let description: String
    public let data: Data
    public let type: PKPushType
    
    public init(payload: PKPushPayload) throws {
        self.description = payload.description
        self.type = payload.type
        self.data = try JSONSerialization.data(withJSONObject: payload.dictionaryPayload)
    }
}
