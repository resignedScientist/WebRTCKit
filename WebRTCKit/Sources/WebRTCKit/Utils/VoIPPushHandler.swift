import PushKit

@MainActor
public protocol VoIPPushHandler {
    func setDelegate(_ delegate: VoIPPushHandlerDelegate)
}

public protocol VoIPPushHandlerDelegate: AnyObject {
    func didReceivePushNotification(payload: PushPayload)
}
