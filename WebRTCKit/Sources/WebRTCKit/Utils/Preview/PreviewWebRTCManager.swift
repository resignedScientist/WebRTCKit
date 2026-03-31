import WebRTC

final class PreviewWebRTCManager: WebRTCManager {
    
    private weak var delegate: WebRTCManagerDelegate?
    private weak var callDelegate: WebRTCManagerCallDelegate?
    
    func setDelegate(_ delegate: WebRTCManagerDelegate?) {
        self.delegate = delegate
    }
    
    func setCallDelegate(_ callDelegate: WebRTCManagerCallDelegate?) {
        self.callDelegate = callDelegate
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
    
    func setLocalAudioMuted(_ isMuted: Bool) {
        
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
    
    func updateImageSize(_ imageSize: CGSize) {
        
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
