import PushKit

@WebRTCActor
public protocol VoIPPushHandler: Sendable {
    func setDelegate(_ delegate: VoIPPushHandlerDelegate)
}

public protocol VoIPPushHandlerDelegate: AnyObject {
    func didReceivePushNotification(payload: PushPayload)
}
