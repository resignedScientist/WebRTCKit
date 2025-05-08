import WebRTC

protocol WRKRTCPeerConnectionDelegate: AnyObject, Sendable {
    
    /// Called when the SignalingState changed.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange stateChanged: RTCSignalingState)
    
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didAdd rtpReceiver: RtpReceiver)
    
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove rtpReceiver: RtpReceiver)
    
    /// Called when negotiation is needed, for example ICE has restarted.
    func peerConnectionShouldNegotiate(_ peerConnection: WRKRTCPeerConnection)
    
    /// Called any time the IceConnectionState changes.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceConnectionState)
    
    /// Called any time the IceGatheringState changes.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceGatheringState)
    
    /// Called any time the PeerConnectionState changes.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCPeerConnectionState)
    
    /// New ice candidate has been found.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didGenerate candidate: ICECandidate)
    
    /// Called when a group of local Ice candidates have been removed.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove candidates: [ICECandidate])
    
    /// New data channel has been opened.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didOpen dataChannel: WRKDataChannel)
}
