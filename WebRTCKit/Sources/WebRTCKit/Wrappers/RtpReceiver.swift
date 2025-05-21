import WebRTC

final class RtpReceiver: @unchecked Sendable {
    
    private let receiver: RTCRtpReceiver
    private let queue = DispatchSerialQueue(label: "RtpReceiverQueue")
    
    var track: RTCMediaStreamTrack? {
        queue.sync {
            receiver.track
        }
    }
    
    init(_ receiver: RTCRtpReceiver) {
        self.receiver = receiver
    }
}
