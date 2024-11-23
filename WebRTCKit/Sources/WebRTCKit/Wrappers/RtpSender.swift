import WebRTC

let sendableQueueKey = DispatchSpecificKey<String>()
let sendableQueueLabel = "com.webrtckit.sendable"
let sendableQueue: DispatchQueue = {
    let queue = DispatchQueue(label: sendableQueueLabel)
    queue.setSpecific(key: sendableQueueKey, value: queue.label)
    return queue
}()

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
        assert(DispatchQueue.getSpecific(key: sendableQueueKey) == sendableQueueLabel)
        return sender
    }
}
