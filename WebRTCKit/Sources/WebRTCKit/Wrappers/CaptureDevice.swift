import AVKit

final class CaptureDevice: @unchecked Sendable {
    
    private let _device: AVCaptureDevice
    private let queue = DispatchQueue(label: "com.webrtckit.captureDevice")
    
    var device: AVCaptureDevice {
        queue.sync {
            _device
        }
    }
    
    var formats: [AVCaptureDevice.Format] {
        queue.sync {
            _device.formats
        }
    }
    
    var activeFormat: AVCaptureDevice.Format {
        get {
            queue.sync {
                _device.activeFormat
            }
        }
        set {
            queue.sync {
                _device.activeFormat = newValue
            }
        }
    }
    
    init?(_ device: AVCaptureDevice?) {
        guard let device else { return nil }
        self._device = device
    }
    
    func lockForConfiguration() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self._device.lockForConfiguration()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func unlockForConfiguration() async {
        return await withCheckedContinuation { continuation in
            queue.async {
                self._device.unlockForConfiguration()
                continuation.resume()
            }
        }
    }
}
