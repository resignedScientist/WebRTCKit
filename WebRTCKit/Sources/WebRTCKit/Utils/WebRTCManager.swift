import WebRTC

public enum WebRTCManagerError: LocalizedError, Equatable {
    
    /// Error when connection to the peer fails.
    case connectionFailed
    
    /// Error indicating that an established connection was lost.
    case connectionLost
    
    /// A critical error with a specific message.
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

@WebRTCActor
protocol WebRTCManagerDelegate: AnyObject, Sendable {
    
    /// Called when a local video track has been added.
    func didAddLocalVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// Called when a remote video track has been added by the peer.
    func didAddRemoteVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// Called when a remote video track has been removed by the peer.
    func didRemoveRemoteVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// Called when a local audio track has been added.
    func didAddLocalAudioTrack(_ audioTrack: WRKRTCAudioTrack)
    
    /// Called when a remote audio track has been added by the peer.
    func didAddRemoteAudioTrack(_ audioTrack: WRKRTCAudioTrack)
    
    /// Called when a remote audio track has been removed by the peer.
    func didRemoveRemoteAudioTrack(_ audioTrack: WRKRTCAudioTrack)
    
    /// Triggered when an end call message is received from the peer.
    func didReceiveEndCall()
    
    /// Triggered when the call has completely ended.
    func callDidEnd()
    
    /// Triggered when a call offer is received from a peer.
    func didReceiveOffer(from peerID: PeerID)
    
    /// Called when the peer accepts a call request.
    func peerDidAcceptCallRequest()
    
    /// Called when a call request is accepted.
    func didAcceptCallRequest()
    
    /// Triggered when the call starts successfully.
    func callDidStart()
    
    /// Triggered whenever there is an error.
    func onError(_ error: WebRTCManagerError)
    
    /// Called when a new data channel is created by the peer.
    func didReceiveDataChannel(_ dataChannel: WRKDataChannel)
    
    /// Called when we lost the connection to our peer.
    func didLosePeerConnection()
}

@WebRTCActor
protocol WebRTCManager: Sendable {
    
    /// Sets the delegate to handle WebRTC events.
    /// - Parameter delegate: A delegate conforming to `WebRTCManagerDelegate`.
    func setDelegate(_ delegate: WebRTCManagerDelegate?)
    
    /// Sets up the WebRTC connection and returns a `PeerID`.
    /// - Returns: A `PeerID` representing the local peer.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func setup() async throws -> PeerID
    
    /// Starts video recording using a specified video capturer.
    /// - Parameter videoCapturer: An optional video capturer to use.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func startVideoRecording(videoCapturer: VideoCapturer?) async throws
    
    /// Stops video recording.
    func stopVideoRecording() async
    
    /// Checks if video recording is currently active.
    /// - Returns: A boolean indicating if video recording is active.
    func isVideoRecording() -> Bool
    
    /// Initiates a video call to a specified peer.
    /// - Parameter peerID: The `PeerID` of the peer to call.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func startVideoCall(to peerID: PeerID) async throws
    
    /// Stops the ongoing video call.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func stopVideoCall() async throws
    
    /// Answers an incoming call.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func answerCall() async throws
    
    /// Disconnects the peer connection while keeping the signaling server connection open.
    func disconnect() async
    
    /// Creates a data channel with the given label and configuration.
    /// - Parameters:
    ///   - label: A label for the data channel.
    ///   - config: Optional configuration for the data channel.
    /// - Returns: An optional `WRKDataChannel` if successful.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func createDataChannel(label: String, config: RTCDataChannelConfiguration?) async throws -> WRKDataChannel?
    
    /// Begins configuration of data channels and other parameters.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func startConfiguration() async throws
    
    /// Completes the configuration process and initiates re-negotiation.
    /// - Throws: Throws `WebRTCManagerError` on failure.
    func commitConfiguration() async throws
}
