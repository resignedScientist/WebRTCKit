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
    
    /// We added a local video track.
    func didAddLocalVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// Our peer added a local video track (which is our remote video track).
    func didAddRemoteVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// Our peer removed his local video track (which is our remote video track).
    func didRemoveRemoteVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// We received an endCall message from our peer and should react to it.
    func didReceiveEndCall()
    
    /// The call did end.
    func callDidEnd()
    
    /// We received a call offer.
    func didReceiveOffer(from peerID: PeerID)
    
    /// Our peer accepted our call request.
    func peerDidAcceptCallRequest()
    
    /// We accepted the call request.
    func didAcceptCallRequest()
    
    /// The call did start successfully. You are now able to open data channels.
    func callDidStart()
    
    /// There was some kind of error.
    func onError(_ error: WebRTCManagerError)
    
    /// Called when the peer created a new data channel.
    func didReceiveDataChannel(_ dataChannel: WRKDataChannel)
}

@WebRTCActor
protocol WebRTCManager: Sendable {
    
    func setDelegate(_ delegate: WebRTCManagerDelegate?)
    
    func setup() async throws -> PeerID
    
    func startVideoRecording(videoCapturer: VideoCapturer?) async throws
    
    func stopVideoRecording() async
    
    /// Was a video track added by calling `startVideoRecording`?
    func isVideoRecording() -> Bool
    
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
