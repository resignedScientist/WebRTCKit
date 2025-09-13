import PushKit
@preconcurrency import CallKit

public final class DefaultVoIPPushHandler: NSObject, VoIPPushHandler {
    
    private let log = Logger(caller: "VoIPPushHandler")
    private let pushRegistry = PKPushRegistry(queue: .main)
    private let store: PushCredentialStoring
    nonisolated private let parser: PushPayloadParser
    nonisolated private let provider: CXProvider
    
    private weak var delegate: VoIPPushHandlerDelegate?
    
    public init(
        store: PushCredentialStoring,
        parser: PushPayloadParser,
        provider: CXProvider
    ) {
        self.store = store
        self.parser = parser
        self.provider = provider
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
    
    public nonisolated func pushRegistry(
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
    
    public nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping @Sendable () -> Void
    ) {
        log.debug("Did receive incoming push notification of type '\(type)'")
        
        do {
            
            let pushPayload = try PushPayload(payload: payload)
            let parsedPayload = try parser.parse(pushPayload)
            let callId = parsedPayload.callId
            let handle = parsedPayload.handle
            
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: handle)
            update.hasVideo = true
            
            provider.reportNewIncomingCall(with: callId, update: update) { [log] error in
                if let error {
                    log.error("Failed to report incoming call - \(error)")
                } else {
                    log.debug("Incoming call reported!")
                }
                completion()
            }
            
            log.debug("Incoming call reported!")
            
            Task { @WebRTCActor in
                delegate?.didReceivePushNotification(payload: pushPayload)
            }
        } catch {
            log.error("didReceiveIncomingPush failed - \(error)")
            
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: "Unknown Caller")
            update.hasVideo = true
            
            let uuid = UUID()
            
            // we must always report the call; due to failure, we immediately end it
            provider.reportNewIncomingCall(with: UUID(), update: update) { [provider] _ in
                completion()
                provider.reportCall(with: uuid, endedAt: .now, reason: .failed)
            }
        }
    }
}
