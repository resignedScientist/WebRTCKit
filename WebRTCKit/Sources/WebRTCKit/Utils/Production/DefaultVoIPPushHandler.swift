import PushKit

enum VoIPPushHandlerError: Error {
    case callManagerBlockedNewCall
}

public final class DefaultVoIPPushHandler: NSObject, VoIPPushHandler {
    
    @Inject(\.providerDelegate) private var providerDelegate
    
    private let log = Logger(caller: "VoIPPushHandler")
    private let pushRegistry = PKPushRegistry(queue: .main)
    private let store: PushCredentialStoring
    private let parser: PushPayloadParser
    
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

extension DefaultVoIPPushHandler: @MainActor PKPushRegistryDelegate {
    
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
        
        log.debug("Did receive incoming push notification of type '\(type)'")
        
        do {
            let pushPayload = try PushPayload(payload: payload)
            let parsedPayload = try parser.parse(pushPayload)
            let callId = parsedPayload.callId
            let handle = parsedPayload.handle
            
            try await providerDelegate.reportNewIncomingCall(uuid: callId, handle: handle)
            
        } catch {
            log.error("Failed to handle incoming push - \(error)")
            
            // we must always report the call; due to failure, we immediately end it
            providerDelegate.reportCallEnded(
                UUID(),
                at: .now,
                with: .failed
            )
        }
    }
}
