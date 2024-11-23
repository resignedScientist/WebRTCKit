import WebRTC

//RTCRtpReceiver

final class RtpReceiver: @unchecked Sendable {
    
    private let receiver: RTCRtpReceiver
    private let queue = DispatchQueue(label: "com.webrtckit.RtpReceiver")
    
    var track: RTCMediaStreamTrack? {
        queue.sync {
            receiver.track
        }
    }
    
    init(_ receiver: RTCRtpReceiver) {
        self.receiver = receiver
    }
}
