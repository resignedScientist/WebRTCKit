import WebRTC

final class VideoCapturer: @unchecked Sendable {
    
    private let videoCapturer: RTCVideoCapturer
    private let queue = DispatchQueue.main
    
    var delegate: RTCVideoCapturerDelegate? {
        get {
            queue.sync {
                videoCapturer.delegate
            }
        }
        set {
            queue.sync {
                videoCapturer.delegate = newValue
            }
        }
    }
    
    init(_ videoCapturer: RTCVideoCapturer) {
        self.videoCapturer = videoCapturer
    }
    
    @MainActor
    func startCapture(
        with device: CaptureDevice,
        fps: Int
    ) async throws {
        
        guard let videoCapturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
        
        try await videoCapturer.startCapture(
            with: device.device,
            format: device.activeFormat,
            fps: 30
        )
    }
    
    func stop() async {
        if videoCapturer is RTCCameraVideoCapturer {
            await withCheckedContinuation { continuation in
                queue.async {
                    guard let videoCapturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
                    videoCapturer.stopCapture {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
