import PushKit

@MainActor
public protocol PushCredentialProviding: Sendable {
    func credentials(for type: PKPushType) async -> PushCredentials?
}
