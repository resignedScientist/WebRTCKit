import WebRTC

public enum WebRTCManagerError: LocalizedError, Equatable {
    case connectionFailed
    case connectionLost
    case critical(_ message: String)
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to our peer."
        case .connectionLost:
            return "The connection was lost."
        case let .critical(message):
            return message
        }
    }
}

// The CallManager conforms to this.
@WebRTCActor
protocol WebRTCManagerDelegate: AnyObject, Sendable {
    
    func didAddLocalVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    func didAddRemoteVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// We received an endCall message from our peer and should react to it.
    func didReceiveEndCall()
    
    /// The call did end.
    func callDidEnd()
    
    func didReceiveOffer(from peerID: PeerID)
    
    func peerDidAcceptCallRequest()
    
    func didAcceptCallRequest()
    
    func callDidStart()
    
    func onError(_ error: WebRTCManagerError)
    
    /// Called when the peer created a new data channel.
    func didReceiveDataChannel(_ dataChannel: WRKDataChannel)
}

@WebRTCActor
protocol WebRTCManager: Sendable {
    
    func setDelegate(_ delegate: WebRTCManagerDelegate?)
    
    func setup() async throws -> PeerID
    
    func startRecording(videoCapturer: RTCVideoCapturer?) async throws
    
    func startVideoCall(to peerID: PeerID) async throws
    
    func stopVideoCall() async throws
    
    func answerCall() async throws
    
    /// Disconnect the peer connection but keep the signaling server connection open.
    func disconnect() async
    
    func createDataChannel(label: String, config: RTCDataChannelConfiguration?) async throws -> WRKDataChannel?
    
    /// Start the configuration of things like data channels and other parameters.
    /// While doing the configuration, there is no re-negotiation happening.
    func startConfiguration() async throws
    
    /// Finish the configuration. After calling it, the re-negotiation is happening.
    func commitConfiguration() async throws
}
