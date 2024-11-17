import WebRTC

final class VideoCapturer: @unchecked Sendable {
    
    private let videoCapturer: RTCVideoCapturer
    private let queue = DispatchQueue(label: "com.webrtckit.VideoCapturer")
    
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
    
    func startCapture(
        with device: CaptureDevice,
        format: AVCaptureDevice.Format,
        fps: Int
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let videoCapturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
                videoCapturer.startCapture(
                    with: device.device,
                    format: format,
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
    }
    
    func start() async throws(PreviewVideoCapturerError) {
        #warning("TODO: this is unsafe!")
        if let videoCapturer = videoCapturer as? PreviewVideoCapturer {
            try await videoCapturer.start()
        }
    }
}
