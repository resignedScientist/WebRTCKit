public protocol PushCredentialStoring: Sendable {
    func store(credentials: PushCredentials) async
}
