import WebRTC

final class PreviewWebRTCManager: WebRTCManager {
    
    private weak var delegate: WebRTCManagerDelegate?
    
    func setDelegate(_ delegate: WebRTCManagerDelegate?) {
        self.delegate = delegate
    }
    
    func setInitialDataChannels(_ dataChannels: [DataChannelSetup]) {
        
    }
    
    func setInitialVideoEnabled(enabled: Bool, imageSize: CGSize, videoCapturer: VideoCapturer?) {
        
    }
    
    func setup() async throws -> PeerID {
        "0000"
    }
    
    func startAudioRecording() async throws {
        
    }
    
    func startVideoRecording(videoCapturer: VideoCapturer?, imageSize: CGSize) async throws {
        
    }
    
    func startVideoCall(to peerID: PeerID) async throws {
        
    }
    
    func stopVideoRecording() async {
        
    }
    
    func stopVideoCall() async {
        
    }
    
    func isVideoRecording() -> Bool {
        false
    }
    
    func answerCall() async throws {
        
    }
    
    func disconnect() async {
        
    }
    
    func createDataChannel(setup: DataChannelSetup) async throws {
        
    }
    
    func startConfiguration() throws {
        
    }
    
    func commitConfiguration() throws {
        
    }
}
