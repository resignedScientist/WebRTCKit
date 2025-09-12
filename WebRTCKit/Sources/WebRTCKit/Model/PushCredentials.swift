import Foundation
import PushKit

public struct PushCredentials: Sendable {
    
    public let description: String
    public let token: Data
    public let type: PKPushType
    
    public init(credentials: PKPushCredentials) {
        self.description = credentials.description
        self.token = credentials.token
        self.type = credentials.type
    }
}
