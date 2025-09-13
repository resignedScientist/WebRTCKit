import PushKit

@MainActor
public protocol VoIPPushHandler: Sendable {
    func setDelegate(_ delegate: VoIPPushHandlerDelegate)
}

public protocol VoIPPushHandlerDelegate: AnyObject {
    @MainActor func didReceivePushNotification(payload: PushPayload)
}
