import PushKit

public actor PushCredentialStore: PushCredentialProviding, PushCredentialStoring {
    
    private var credentials: [PKPushType: PushCredentials] = [:]
    
    public func store(credentials: PushCredentials) async {
        self.credentials[credentials.type] = credentials
    }
    
    public func credentials(for type: PKPushType) async -> PushCredentials? {
        credentials[type]
    }
}
