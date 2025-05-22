import WebRTC

final class RtpSender: @unchecked Sendable {
    
    private let sender: RTCRtpSender
    private let queue = WebRTCActor.queue
    
    var track: RTCMediaStreamTrack? {
        WebRTCActor.checkSync {
            sender.track
        }
    }
    
    var parameters: RTCRtpParameters {
        get {
            WebRTCActor.checkSync {
                sender.parameters
            }
        }
        set {
            WebRTCActor.checkSync {
                sender.parameters = newValue
            }
        }
    }
    
    init(sender: RTCRtpSender) {
        self.sender = sender
    }
    
    func unwrapUnsafely() -> RTCRtpSender {
        assert(WebRTCActor.isRunningOnQueue())
        return sender
    }
}
