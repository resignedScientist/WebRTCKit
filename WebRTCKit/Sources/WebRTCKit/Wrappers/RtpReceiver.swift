import WebRTC

@MainActor
final class RtpReceiver: Sendable {
    
    private let receiver: RTCRtpReceiver
    
    var track: RTCMediaStreamTrack? {
        receiver.track
    }
    
    init(_ receiver: RTCRtpReceiver) {
        self.receiver = receiver
    }
}
