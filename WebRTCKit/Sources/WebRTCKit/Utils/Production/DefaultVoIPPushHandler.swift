import PushKit

enum VoIPPushHandlerError: Error {
    case callManagerBlockedNewCall
}

public final class DefaultVoIPPushHandler: NSObject, VoIPPushHandler {
    
    @Inject(\.providerDelegate) private var providerDelegate
    
    private let log = Logger(caller: "VoIPPushHandler")
    private let pushRegistry = PKPushRegistry(queue: .main)
    private let store: PushCredentialStoring
    nonisolated private let parser: PushPayloadParser
    
    private weak var delegate: VoIPPushHandlerDelegate?
    
    public init(
        store: PushCredentialStoring,
        parser: PushPayloadParser
    ) {
        self.store = store
        self.parser = parser
        super.init()
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        if let token = pushRegistry.pushToken(for: .voIP) {
            log.info("Saving VoIP Push token")
            Task {
                await store.store(
                    credentials: PushCredentials(
                        token: token,
                        type: .voIP
                    )
                )
            }
        }
        log.info("Registered for receiving VoIP push notifications.")
    }
    
    public func setDelegate(_ delegate: VoIPPushHandlerDelegate) {
        self.delegate = delegate
    }
}

// MARK: - PKPushRegistryDelegate

extension DefaultVoIPPushHandler: PKPushRegistryDelegate {
    
    public func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        
        log.debug("Did update push credentials for type '\(type)'")
        
        let credentials = PushCredentials(credentials: pushCredentials)
        Task {
            await store.store(credentials: credentials)
        }
    }
    
    public func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType
    ) async {
        
        guard
            let uuidString = payload.dictionaryPayload["UUID"] as? String,
            let handle = payload.dictionaryPayload["handle"] as? String,
            let uuid = UUID(uuidString: uuidString)
        else { return }
        
        log.debug("Did receive incoming push notification of type '\(type)'")
        
        do {
            try await providerDelegate.reportNewIncomingCall(uuid: uuid, handle: handle)
        } catch {
            print("reportNewIncomingCall failed - \(error)")
        }
    }
}
