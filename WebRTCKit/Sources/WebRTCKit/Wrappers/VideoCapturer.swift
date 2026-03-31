import WebRTC

@MainActor
final class VideoCapturer {
    
    private let videoCapturer: RTCVideoCapturer
    
    var delegate: RTCVideoCapturerDelegate? {
        get {
            videoCapturer.delegate
        }
        set {
            videoCapturer.delegate = newValue
        }
    }
    
    init(_ videoCapturer: RTCVideoCapturer) {
        self.videoCapturer = videoCapturer
    }
    
    func startCapture(
        with device: CaptureDevice,
        fps: Int
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            guard let videoCapturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
            videoCapturer.startCapture(
                with: device.device,
                format: device.activeFormat,
                fps: fps
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func stop() async {
        if videoCapturer is RTCCameraVideoCapturer {
            await withCheckedContinuation { continuation in
                guard let videoCapturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
                videoCapturer.stopCapture {
                    continuation.resume()
                }
            }
        }
    }
}
