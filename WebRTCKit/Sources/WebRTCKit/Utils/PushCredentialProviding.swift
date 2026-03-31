import PushKit

public protocol PushCredentialProviding {
    func credentials(for type: PKPushType) async -> PushCredentials?
}
