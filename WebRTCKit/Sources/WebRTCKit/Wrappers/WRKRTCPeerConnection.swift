import WebRTC

@WebRTCActor
protocol WRKRTCPeerConnection: Sendable {
    
    /// The object that will be notifed about events such as state changes and
    /// streams being added or removed.
    var delegate: WRKRTCPeerConnectionDelegate? { get }
    
    var iceGatheringState: RTCIceGatheringState { get }
    
    var iceConnectionState: RTCIceConnectionState { get }
    
    var signalingState: RTCSignalingState { get }
    
    var localDescription: RTCSessionDescription? { get }
    
    var remoteDescription: RTCSessionDescription? { get }
    
    /// Gets all RTCRtpSenders associated with this peer connection.
    /// Note: reading this property returns different instances of RTCRtpSender.
    /// Use isEqual: instead of == to compare RTCRtpSender instances.
    var senders: [RTCRtpSender] { get }
    
    @discardableResult
    func add(_ track: WRKRTCMediaStreamTrack, streamIds: [String]) -> RTCRtpSender?
    
    /// Provide a remote candidate to the ICE Agent.
    func add(_ candidate: ICECandidate) async throws
    
    /// Generate an SDP offer.
    nonisolated func offer(for constraints: MediaConstraints) async throws -> SessionDescription
    
    /// Creates an offer or answer (depending on current signaling state) and sets
    /// it as the local session description.
    func setLocalDescription() async throws
    
    /// Apply the supplied RTCSessionDescription as the local description.
    func setLocalDescription(_ sdp: SessionDescription) async throws
    
    /// Apply the supplied RTCSessionDescription as the remote description.
    func setRemoteDescription(_ sdp: SessionDescription) async throws
    
    /// Generate an SDP answer.
    nonisolated func answer(for constraints: MediaConstraints) async throws -> SessionDescription
    
    /// Create a new data channel with the given label and configuration.
    func dataChannel(forLabel label: String, configuration: RTCDataChannelConfiguration) -> WRKDataChannel?
    
    /// Terminate all media and close the transport.
    func close()
    
    /// Tells the PeerConnection that ICE should be restarted. This triggers a need
    /// for negotiation and subsequent offerForConstraints:completionHandler call will act as if
    /// RTCOfferAnswerOptions::ice_restart is true.
    func restartIce()
    
    /// Gather statistic through the v2 statistics API.
    func statistics() async -> StatisticsReport
}

final class WRKRTCPeerConnectionImpl: NSObject, WRKRTCPeerConnection {
    
    weak var delegate: WRKRTCPeerConnectionDelegate?
    
    let peerConnection: RTCPeerConnection
    
    var iceGatheringState: RTCIceGatheringState {
        peerConnection.iceGatheringState
    }
    
    var iceConnectionState: RTCIceConnectionState {
        peerConnection.iceConnectionState
    }
    
    var localDescription: RTCSessionDescription? {
        peerConnection.localDescription
    }
    
    var remoteDescription: RTCSessionDescription? {
        peerConnection.remoteDescription
    }
    
    var signalingState: RTCSignalingState {
        peerConnection.signalingState
    }
    
    var senders: [RTCRtpSender] {
        peerConnection.senders
    }
    
    init(_ peerConnection: RTCPeerConnection, delegate: WRKRTCPeerConnectionDelegate? = nil) {
        self.peerConnection = peerConnection
        self.delegate = delegate
        super.init()
        peerConnection.delegate = self
    }
    
    func add(_ track: WRKRTCMediaStreamTrack, streamIds: [String]) -> RTCRtpSender? {
        if let audioTrack = (track as? WRKRTCAudioTrackImpl)?.audioTrack {
            return peerConnection.add(audioTrack, streamIds: streamIds)
        } else if let videoTrack = (track as? WRKRTCVideoTrackImpl)?.videoTrack {
            return peerConnection.add(videoTrack, streamIds: streamIds)
        }
        return nil
    }
    
    func add(_ candidate: ICECandidate) async throws {
        try await peerConnection.add(candidate.toRTCIceCandidate())
    }
    
    nonisolated func offer(for constraints: MediaConstraints) async throws -> SessionDescription {
        let sdp = try await peerConnection.offer(for: RTCMediaConstraints(
            mandatoryConstraints: constraints.mandatoryConstraints,
            optionalConstraints: constraints.optionalConstraints
        ))
        return SessionDescription(from: sdp)
    }
    
    func setLocalDescription() async throws {
        try await peerConnection.setLocalDescription()
    }
    
    func setLocalDescription(_ sdp: SessionDescription) async throws {
        try await peerConnection.setLocalDescription(sdp.toRTCSessionDescription())
    }
    
    func setRemoteDescription(_ sdp: SessionDescription) async throws {
        try await peerConnection.setRemoteDescription(sdp.toRTCSessionDescription())
    }
    
    func answer(for constraints: MediaConstraints) async throws -> SessionDescription {
        let sdp = try await peerConnection.answer(for: RTCMediaConstraints(
            mandatoryConstraints: constraints.mandatoryConstraints,
            optionalConstraints: constraints.optionalConstraints
        ))
        return SessionDescription(from: sdp)
    }
    
    func dataChannel(forLabel label: String, configuration: RTCDataChannelConfiguration) -> WRKDataChannel? {
        if let dataChannel = peerConnection.dataChannel(forLabel: label, configuration: configuration) {
            return WRKDataChannelImpl(dataChannel)
        }
        return nil
    }
    
    func close() {
        peerConnection.close()
    }
    
    func restartIce() {
        peerConnection.restartIce()
    }
    
    nonisolated func statistics() async -> StatisticsReport {
        let statistics = await peerConnection.statistics()
        return StatisticsReport(statistics: statistics.statistics)
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WRKRTCPeerConnectionImpl: RTCPeerConnectionDelegate {
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(self, didChange: stateChanged)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(self, didAdd: WRKMediaStreamImpl(stream))
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(self, didRemove: WRKMediaStreamImpl(stream))
        }
    }
    
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnectionShouldNegotiate(self)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(self, didChange: newState)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(self, didChange: newState)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(peerConnection, didChange: newState)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let candidate = ICECandidate(from: candidate)
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(self, didGenerate: candidate)
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        let candidates = candidates.map {
            ICECandidate(from: $0)
        }
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(self, didRemove: candidates)
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Task { [weak self] in
            guard let self else { return }
            await delegate?.peerConnection(self, didOpen: dataChannel)
        }
    }
}
