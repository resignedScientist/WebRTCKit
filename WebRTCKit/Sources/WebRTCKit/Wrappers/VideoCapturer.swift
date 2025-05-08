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
        fps: Int
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let videoCapturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
                DispatchQueue.main.async {
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
        }
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
