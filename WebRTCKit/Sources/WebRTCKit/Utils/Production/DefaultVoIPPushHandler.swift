import PushKit

final class DefaultVoIPPushHandler: NSObject, VoIPPushHandler {
    
    public override init() {
        super.init()
        let pushRegistry = PKPushRegistry(queue: .main)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        print("ℹ️ Registered for receiving VoIP push notifications.")
    }
}

// MARK: - PKPushRegistryDelegate

extension DefaultVoIPPushHandler: PKPushRegistryDelegate {
    
    nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        print("🪲 Push Registry did update push credentials.")
        // TODO
    }
    
    nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType
    ) async {
        print("🪲 Push Registry did receive incoming push notification.")
        // TODO
    }
}
