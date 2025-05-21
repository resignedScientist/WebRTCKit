import WebRTC

protocol WRKRTCPeerConnection: Sendable {
    
    /// The object that will be notifed about events such as state changes and
    /// streams being added or removed.
    var delegate: WRKRTCPeerConnectionDelegate? { get }
    
    var iceGatheringState: RTCIceGatheringState { get }
    
    var iceConnectionState: RTCIceConnectionState { get }
    
    var signalingState: RTCSignalingState { get }
    
    var connectionState: RTCPeerConnectionState { get }
    
    var localDescription: RTCSessionDescription? { get }
    
    var remoteDescription: RTCSessionDescription? { get }
    
    /// Gets all RTCRtpSenders associated with this peer connection.
    /// Note: reading this property returns different instances of RTCRtpSender.
    /// Use isEqual: instead of == to compare RTCRtpSender instances.
    var senders: [RtpSender] { get }
    
    /// Gets all RTCRtpReceivers associated with this peer connection.
    /// Note: reading this property returns different instances of RTCRtpReceiver.
    /// Use isEqual: instead of == to compare RTCRtpReceiver instances.
    var receivers: [RTCRtpReceiver] { get }
    
    @discardableResult
    func add(_ track: WRKRTCMediaStreamTrack, streamIds: [String]) async -> RtpSender?
    
    @discardableResult
    func removeTrack(_ sender: RtpSender) async -> Bool
    
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

final class WRKRTCPeerConnectionImpl: NSObject, WRKRTCPeerConnection, @unchecked Sendable {
    
    private weak var _delegate: WRKRTCPeerConnectionDelegate?
    private let _peerConnection: RTCPeerConnection
    private let queue = DispatchSerialQueue(label: "PeerConnectionQueue")
    
    var peerConnection: RTCPeerConnection {
        queue.sync {
            _peerConnection
        }
    }
    
    var delegate: WRKRTCPeerConnectionDelegate? {
        get {
            queue.sync {
                _delegate
            }
        }
        set {
            queue.sync {
                _delegate = newValue
            }
        }
    }
    
    var iceGatheringState: RTCIceGatheringState {
        _peerConnection.iceGatheringState
    }
    
    var iceConnectionState: RTCIceConnectionState {
        _peerConnection.iceConnectionState
    }
    
    var connectionState: RTCPeerConnectionState {
        _peerConnection.connectionState
    }
    
    var localDescription: RTCSessionDescription? {
        _peerConnection.localDescription
    }
    
    var remoteDescription: RTCSessionDescription? {
        _peerConnection.remoteDescription
    }
    
    var signalingState: RTCSignalingState {
        _peerConnection.signalingState
    }
    
    var senders: [RtpSender] {
        _peerConnection.senders.map {
            RtpSender(sender: $0)
        }
    }
    
    var receivers: [RTCRtpReceiver] {
        _peerConnection.receivers
    }
    
    init(_ peerConnection: RTCPeerConnection, delegate: WRKRTCPeerConnectionDelegate? = nil) {
        self._peerConnection = peerConnection
        self._delegate = delegate
        super.init()
        _peerConnection.delegate = self
    }
    
    func add(_ track: WRKRTCMediaStreamTrack, streamIds: [String]) async -> RtpSender? {
        return await withCheckedContinuation { continuation in
            queue.async {
                if let audioTrack = (track as? WRKRTCAudioTrackImpl)?.audioTrack {
                    if let sender = self._peerConnection.add(audioTrack, streamIds: streamIds) {
                        let rtpSender = RtpSender(sender: sender)
                        continuation.resume(returning: rtpSender)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else if let videoTrack = (track as? WRKRTCVideoTrackImpl)?.videoTrack {
                    if let sender = self._peerConnection.add(videoTrack, streamIds: streamIds) {
                        let rtpSender = RtpSender(sender: sender)
                        continuation.resume(returning: rtpSender)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func removeTrack(_ sender: RtpSender) async -> Bool {
        return await withCheckedContinuation { continuation in
            queue.async {
                let result = self._peerConnection.removeTrack(sender.unwrapUnsafely())
                continuation.resume(returning: result)
            }
        }
    }
    
    func add(_ candidate: ICECandidate) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self._peerConnection.add(candidate.toRTCIceCandidate()) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    nonisolated func offer(for constraints: MediaConstraints) async throws -> SessionDescription {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self._peerConnection.offer(for: RTCMediaConstraints(
                    mandatoryConstraints: constraints.mandatoryConstraints,
                    optionalConstraints: constraints.optionalConstraints
                )) { sdp, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        let sdp = SessionDescription(from: sdp!)
                        continuation.resume(returning: sdp)
                    }
                }
            }
        }
    }
    
    func setLocalDescription() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self._peerConnection.setLocalDescriptionWithCompletionHandler { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    func setLocalDescription(_ sdp: SessionDescription) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self._peerConnection.setLocalDescription(sdp.toRTCSessionDescription()) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    func setRemoteDescription(_ sdp: SessionDescription) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self._peerConnection.setRemoteDescription(sdp.toRTCSessionDescription()) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    func answer(for constraints: MediaConstraints) async throws -> SessionDescription {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self._peerConnection.answer(for: RTCMediaConstraints(
                    mandatoryConstraints: constraints.mandatoryConstraints,
                    optionalConstraints: constraints.optionalConstraints
                )) { sdp, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        let sdp = SessionDescription(from: sdp!)
                        continuation.resume(returning: sdp)
                    }
                }
            }
        }
    }
    
    func dataChannel(forLabel label: String, configuration: RTCDataChannelConfiguration) -> WRKDataChannel? {
        if let dataChannel = _peerConnection.dataChannel(forLabel: label, configuration: configuration) {
            return WRKDataChannelImpl(dataChannel)
        }
        return nil
    }
    
    func close() {
        queue.async {
            self._peerConnection.close()
        }
    }
    
    func restartIce() {
        queue.async {
            self._peerConnection.restartIce()
        }
    }
    
    nonisolated func statistics() async -> StatisticsReport {
        return await withCheckedContinuation { continuation in
            queue.async {
                self._peerConnection.statistics { statistics in
                    let report = StatisticsReport(statistics: statistics.statistics)
                    continuation.resume(returning: report)
                }
            }
        }
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WRKRTCPeerConnectionImpl: RTCPeerConnectionDelegate {
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        queue.async {
            self._delegate?.peerConnection(self, didChange: stateChanged)
        }
    }
    
    /// legacy code for plan B, not use for unified semantics
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    
    /// legacy code for plan B, not use for unified semantics
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        let receiver = RtpReceiver(rtpReceiver)
        queue.async {
            self._delegate?.peerConnection(self, didAdd: receiver)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove rtpReceiver: RTCRtpReceiver) {
        let receiver = RtpReceiver(rtpReceiver)
        queue.async {
            self._delegate?.peerConnection(self, didRemove: receiver)
        }
    }
    
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        queue.async {
            self._delegate?.peerConnectionShouldNegotiate(self)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        queue.async {
            self._delegate?.peerConnection(self, didChange: newState)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        queue.async {
            self._delegate?.peerConnection(self, didChange: newState)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        queue.async {
            self._delegate?.peerConnection(self, didChange: newState)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let candidate = ICECandidate(from: candidate)
        queue.async {
            self._delegate?.peerConnection(self, didGenerate: candidate)
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        let candidates = candidates.map {
            ICECandidate(from: $0)
        }
        queue.async {
            self._delegate?.peerConnection(self, didRemove: candidates)
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        let dataChannel = WRKDataChannelImpl(dataChannel)
        queue.sync {
            _delegate?.peerConnection(self, didOpen: dataChannel)
        }
    }
}
