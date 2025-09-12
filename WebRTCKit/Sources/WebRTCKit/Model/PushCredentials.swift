import Foundation
import PushKit

public struct PushCredentials: Sendable {
    public let token: Data
    public let type: PKPushType
}

extension PushCredentials {
    
    public init(credentials: PKPushCredentials) {
        self.token = credentials.token
        self.type = credentials.type
    }
}
