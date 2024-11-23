import WebRTC

final class PreviewWebRTCManager: WebRTCManager {
    
    private weak var delegate: WebRTCManagerDelegate?
    
    func setDelegate(_ delegate: WebRTCManagerDelegate?) {
        self.delegate = delegate
    }
    
    func setup() async throws -> PeerID {
        "0000"
    }
    
    func startVideoRecording(videoCapturer: VideoCapturer?) async throws {
        
    }
    
    func startVideoCall(to peerID: PeerID) async throws {
        
    }
    
    func stopVideoRecording() async {
        
    }
    
    func stopVideoCall() async {
        
    }
    
    func answerCall() async throws {
        
    }
    
    func disconnect() async {
        
    }
    
    func createDataChannel(label: String, config: RTCDataChannelConfiguration?) throws -> WRKDataChannel? {
        nil
    }
    
    func startConfiguration() throws {
        
    }
    
    func commitConfiguration() throws {
        
    }
}
