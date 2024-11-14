import WebRTC

protocol WRKRTCPeerConnectionDelegate: AnyObject, Sendable {
    
    /// Called when the SignalingState changed.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange stateChanged: RTCSignalingState)
    
    /// Called when media is received on a new stream from remote peer.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didAdd stream: WRKMediaStream)
    
    /// Called when a remote peer closes a stream.
    /// This is not called when RTCSdpSemanticsUnifiedPlan is specified.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove stream: WRKMediaStream)
    
    /// Called when negotiation is needed, for example ICE has restarted.
    func peerConnectionShouldNegotiate(_ peerConnection: WRKRTCPeerConnection)
    
    /// Called any time the IceConnectionState changes.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceConnectionState)
    
    /// Called any time the IceGatheringState changes.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceGatheringState)
    
    /// Called any time the PeerConnectionState changes.
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState)
    
    /// New ice candidate has been found.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didGenerate candidate: RTCIceCandidate)
    
    /// Called when a group of local Ice candidates have been removed.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove candidates: [RTCIceCandidate])
    
    /// New data channel has been opened.
    func peerConnection(_ peerConnection: WRKRTCPeerConnection, didOpen dataChannel: RTCDataChannel)
}
