import AVKit

final class CaptureDevice: @unchecked Sendable {
    
    private let _device: AVCaptureDevice
    private let queue = WebRTCActor.queue
    
    var device: AVCaptureDevice {
        WebRTCActor.checkSync {
            _device
        }
    }
    
    var formats: [AVCaptureDevice.Format] {
        WebRTCActor.checkSync {
            _device.formats
        }
    }
    
    var activeFormat: AVCaptureDevice.Format {
        get {
            WebRTCActor.checkSync {
                _device.activeFormat
            }
        }
        set {
            WebRTCActor.checkSync {
                _device.activeFormat = newValue
            }
        }
    }
    
    init?(_ device: AVCaptureDevice?) {
        guard let device else { return nil }
        self._device = device
    }
    
    @WebRTCActor
    func lockForConfiguration() throws {
        try _device.lockForConfiguration()
    }
    
    @WebRTCActor
    func unlockForConfiguration() {
        _device.unlockForConfiguration()
    }
}
