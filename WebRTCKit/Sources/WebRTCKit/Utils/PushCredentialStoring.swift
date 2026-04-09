
@MainActor
public protocol PushCredentialStoring {
    func store(credentials: PushCredentials) async
}
