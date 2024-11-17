import WebRTC

final class RtpSender: @unchecked Sendable {
    
    private let sender: RTCRtpSender
    private let queue = DispatchQueue(label: "com.webrtckit.RtpSender")
    
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
}
