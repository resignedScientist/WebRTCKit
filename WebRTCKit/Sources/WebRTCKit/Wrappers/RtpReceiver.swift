import WebRTC

final class RtpReceiver: @unchecked Sendable {
    
    private let receiver: RTCRtpReceiver
    private let queue = WebRTCActor.queue
    
    var track: RTCMediaStreamTrack? {
        WebRTCActor.checkSync {
            receiver.track
        }
    }
    
    init(_ receiver: RTCRtpReceiver) {
        self.receiver = receiver
    }
}
