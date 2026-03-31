import AVKit

final class CaptureDevice {
    
    private let _device: AVCaptureDevice
    
    var device: AVCaptureDevice {
        _device
    }
    
    var formats: [AVCaptureDevice.Format] {
        _device.formats
    }
    
    var activeFormat: AVCaptureDevice.Format {
        get {
            _device.activeFormat
        }
        set {
            _device.activeFormat = newValue
        }
    }
    
    init?(_ device: AVCaptureDevice?) {
        guard let device else { return nil }
        self._device = device
    }
    
    func lockForConfiguration() throws {
        try _device.lockForConfiguration()
    }
    
    func unlockForConfiguration() {
        _device.unlockForConfiguration()
    }
}
