import WebRTC

final class RtpReceiver {
    
    private let receiver: RTCRtpReceiver
    
    var track: RTCMediaStreamTrack? {
        receiver.track
    }
    
    init(_ receiver: RTCRtpReceiver) {
        self.receiver = receiver
    }
}
