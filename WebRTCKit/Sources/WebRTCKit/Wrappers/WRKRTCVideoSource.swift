import WebRTC

protocol WRKRTCVideoSource: AnyObject, RTCVideoCapturerDelegate {
    
}

class WRKRTCVideoSourceImpl: NSObject, WRKRTCVideoSource {
    
    let videoSource: RTCVideoSource
    
    init(_ videoSource: RTCVideoSource) {
        self.videoSource = videoSource
    }
}

// MARK: - RTCVideoCapturerDelegate

extension WRKRTCVideoSourceImpl {
    
    func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {
        videoSource.capturer(capturer, didCapture: frame)
    }
}
