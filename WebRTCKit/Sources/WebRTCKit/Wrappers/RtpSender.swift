import WebRTC

final class RtpSender {
    
    private let sender: RTCRtpSender
    
    var track: RTCMediaStreamTrack? {
        sender.track
    }
    
    var parameters: RTCRtpParameters {
        get {
            sender.parameters
        }
        set {
            sender.parameters = newValue
        }
    }
    
    init(sender: RTCRtpSender) {
        self.sender = sender
    }
    
    func unwrapUnsafely() -> RTCRtpSender {
        assert(RunLoop.current == .main)
        return sender
    }
}
