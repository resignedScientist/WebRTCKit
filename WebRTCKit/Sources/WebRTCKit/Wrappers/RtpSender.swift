import WebRTC

let sendableQueue = DispatchQueue(label: "com.webrtckit.sendable")

final class RtpSender: @unchecked Sendable {
    
    private let sender: RTCRtpSender
    private let queue = sendableQueue
    
    var track: RTCMediaStreamTrack? {
        queue.sync {
            sender.track
        }
    }
    
    var parameters: RTCRtpParameters {
        get {
            queue.sync {
                sender.parameters
            }
        }
        set {
            queue.sync {
                sender.parameters = newValue
            }
        }
    }
    
    init(sender: RTCRtpSender) {
        self.sender = sender
    }
    
    func unwrapUnsafely() -> RTCRtpSender {
        assert(RunLoop.current == queue)
        return sender
    }
}
