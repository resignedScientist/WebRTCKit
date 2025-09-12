import PushKit

public final class DefaultVoIPPushHandler: NSObject, VoIPPushHandler {
    
    private let log = Logger(caller: "VoIPPushHandler")
    private let pushRegistry = PKPushRegistry(queue: WebRTCActor.queue)
    private let store: PushCredentialStoring
    
    private weak var delegate: VoIPPushHandlerDelegate?
    
    public init(store: PushCredentialStoring) {
        self.store = store
        super.init()
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        log.info("Registered for receiving VoIP push notifications.")
    }
    
    public func setDelegate(_ delegate: VoIPPushHandlerDelegate) {
        self.delegate = delegate
    }
}

// MARK: - PKPushRegistryDelegate

extension DefaultVoIPPushHandler: PKPushRegistryDelegate {
    
    public nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        
        log.debug("🪲 Did update push credentials for type '\(type)'")
        
        let credentials = PushCredentials(credentials: pushCredentials)
        Task {
            await store.store(credentials: credentials)
        }
    }
    
    public nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType
    ) async {
        
        log.debug("🪲 Did receive incoming push notification of type '\(type)'")
        
        do {
            let pushPayload = try PushPayload(payload: payload)
            Task { @WebRTCActor in
                delegate?.didReceivePushNotification(payload: pushPayload)
            }
        } catch {
            log.error("Failed to encode push payload - \(error)")
        }
    }
}
