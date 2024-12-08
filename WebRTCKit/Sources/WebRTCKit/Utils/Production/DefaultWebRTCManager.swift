import WebRTC

final class DefaultWebRTCManager: NSObject, WebRTCManager {
    
    weak var delegate: WebRTCManagerDelegate?
    
    @Inject(\.callProvider) private var callProvider
    @Inject(\.signalingServer) private var signalingServer
    @Inject(\.config) private var config
    
    private let factory: WRKRTCPeerConnectionFactory
    private let rtcAudioSession: WRKRTCAudioSession
    private let bitrateAdjustor: BitrateAdjustor = BitrateAdjustorImpl()
    
    private var peerConnection: WRKRTCPeerConnection?
    private var videoCapturer: VideoCapturer?
    private var videoSource: WRKRTCVideoSource?
    private var remoteAudioTrack: WRKRTCAudioTrack?
    private var remoteVideoTrack: WRKRTCVideoTrack?
    private var localAudioTrack: WRKRTCAudioTrack?
    private var localVideoTrack: WRKRTCVideoTrack?
    private var localVideoSender: RtpSender?
    private var localPeerID: PeerID?
    private var remotePeerID: PeerID?
    
    /// Cache of received ICE candidates that are processed when our peerConnection is ready.
    private var cachedICECandidates = ICECandidateCache()
    
    /// The offer SDP coming from the other peer that is cached until the user answers the call.
    private var receivedOfferSDP: SessionDescription?
    
    /// Does this peer should act 'polite' as defined in the 'perfect negotiation' pattern?
    private var isPolite = false
    
    /// Does this peer currently prepare an offer?
    private var isPreparingOffer = false
    
    /// Is the configuration of data channels and other parameters running?
    private var isConfigurating = false
    
    /// Did we postpone the negotiation sdp until the signaling state is stable?
    private var isCommitConfigurationPostponed = false
    
    /// Is the call running?
    private var callIsRunning = false
    
    /// Are we currently processing cached ICE candidates?
    private var isProcessingCandidates = false
    
    init(
        factory: WRKRTCPeerConnectionFactory,
        rtcAudioSession: WRKRTCAudioSession = WRKRTCAudioSessionImpl(.sharedInstance())
    ) {
        self.factory = factory
        self.rtcAudioSession = rtcAudioSession
        
        super.init()
        
        // configure audio session
        rtcAudioSession.useManualAudio = true
    }
    
    func setDelegate(_ delegate: WebRTCManagerDelegate?) {
        self.delegate = delegate
    }
    
    @discardableResult
    func setup() async throws -> PeerID {
        
        guard peerConnection == nil else {
            
            // already properly set up
            if let localPeerID {
                return localPeerID
            }
            
            // something went seriously wrong
            throw WebRTCManagerError.critical("⚠️ Setup failed; We already have a peer connection.")
        }
        
        // connect to signaling server
        let peerID = try await connectToSignalingServer()
        self.localPeerID = peerID
        
        // create peer connection
        let peerConnection = try await makePeerConnection()
        self.peerConnection = peerConnection
        
        // add the audio track to the peer connection
        if let localAudioTrack {
            await peerConnection.add(localAudioTrack, streamIds: ["localStream"])
        } else {
            await addAudioTrack(to: peerConnection)
        }
        
        bitrateAdjustor.start(for: .audio, peerConnection: peerConnection)
        
        return peerID
    }
    
    func startVideoRecording(videoCapturer: VideoCapturer? = nil) async throws {
        guard let peerConnection else {
            throw WebRTCManagerError.critical("startVideoRecording failed; Missing peer connection. Did you call setup()?")
        }
        
        guard !peerConnection.senders.contains(where: { $0.track?.kind == "video" }) else {
            print("ℹ️ Peer connection already contains a video track; we remove the old one and add a new one.")
            await stopVideoRecording()
            try await startVideoRecording(videoCapturer: videoCapturer)
            return
        }
        
        // add the video track to the peer connection
        if let localVideoTrack {
            localVideoSender = await peerConnection.add(localVideoTrack, streamIds: ["localStream"])
        } else {
            await addVideoTrack(to: peerConnection)
        }
        
        let videoDevice = CaptureDevice(
            AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            )
        )
        
        if videoDevice == nil {
            
            // We do not have a capturing device,
            // so we are assuming, we are running on the simulator.
            // -> We use an example video as input
            
            print("ℹ️ Did not find a capturing device. Using example video as input.")
            
            guard let videoSource else { return }
            
            let videoCapturer = VideoCapturer(
                PreviewVideoCapturer(delegate: videoSource)
            )
            
            // start playing video
            try await videoCapturer.start()
            
            self.videoCapturer = videoCapturer
        } else if let videoCapturer { // use custom input
            videoCapturer.delegate = videoSource
            self.videoCapturer = videoCapturer
        } else {
            
            // use default front camera as input
            
            guard
                let videoDevice,
                let format = videoDevice.formats.last(where: { format in
                    let resolution = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    return resolution.height <= 480
                }),
                let videoSource
            else { return }
            
            // set resolution
            try await videoDevice.lockForConfiguration()
            videoDevice.activeFormat = format
            await videoDevice.unlockForConfiguration()
            
            // setup video capturer
            let videoCapturer = VideoCapturer(
                RTCCameraVideoCapturer(delegate: videoSource)
            )
            self.videoCapturer = videoCapturer
            
            // start capturing video
            try await videoCapturer.startCapture(
                with: videoDevice,
                fps: 30
            )
        }
        
        // start bitrate adjustor
        bitrateAdjustor.start(for: .video, peerConnection: peerConnection)
    }
    
    func stopVideoRecording() async {
        
        // stop video capturer
        async let stopVideoCapturer: Void? = videoCapturer?.stop()
        
        // remove video track
        if let peerConnection, let localVideoSender {
            await peerConnection.removeTrack(localVideoSender)
            self.localVideoSender = nil
            localVideoTrack = nil
            print("ℹ️ Local video track removed.")
        } else {
            print("ℹ️ Video sender is nil. No video track to remove.")
        }
        
        await stopVideoCapturer
        videoCapturer = nil
        
        // stop bitrate adjustor for video
        await bitrateAdjustor.stop(for: .video)
        
        print("ℹ️ Video recording stopped.")
    }
    
    func startVideoCall(to peerID: PeerID) async throws {
        guard let peerConnection else {
            throw WebRTCManagerError.critical("⚠️ startVideoCall failed; Missing peer connection. Did you call setup()?")
        }
        
        self.remotePeerID = peerID
        
        try await sendOffer(
            to: peerID,
            peerConnection: peerConnection
        )
    }
    
    func stopVideoCall() async throws {
        guard peerConnection != nil else { return }
        
        print("ℹ️ Stopping video call…")
        
        // send end call message to our peer
        if let remotePeerID {
            do {
                try await signalingServer.sendEndCall(to: remotePeerID)
            } catch {
                print("⚠️ Failed to send 'end call' message to our peer.")
            }
        }

        await disconnect()
        delegate?.callDidEnd()
    }

    func answerCall() async throws {
        guard let peerConnection, let remotePeerID, let receivedOfferSDP else { return }
        
        try await peerConnection.setRemoteDescription(receivedOfferSDP)
        
        // send answer
        try await sendAnswer(to: remotePeerID, peerConnection: peerConnection)
        
        delegate?.didAcceptCallRequest()
        
        // check if we are already connected
        if [.connected, .completed].contains(peerConnection.iceConnectionState) {
            callDidStart()
        }
        
        // process ICE candidates
        await processCachedCandidates()
    }
    
    func disconnect() async {
        peerConnection?.close()
        peerConnection = nil
        remoteAudioTrack = nil
        remoteVideoTrack = nil
        remotePeerID = nil
        receivedOfferSDP = nil
        callIsRunning = false
        await bitrateAdjustor.stop()
        await cachedICECandidates.clear()
    }
    
    func createDataChannel(label: String, config: RTCDataChannelConfiguration?) async throws -> WRKDataChannel? {
        guard let peerConnection else {
            throw WebRTCManagerError.critical(
                "⚠️ called createDataChannel, but peerConnection is nil; Did you call setup()?"
            )
        }
        
        guard [.connected, .completed].contains(peerConnection.iceConnectionState) else {
            throw WebRTCManagerError.critical("⚠️ Tried to create a data channel before the call is running.")
        }
        
        guard peerConnection.signalingState == .stable else {
            throw WebRTCManagerError.critical("⚠️ Tried to create a data channel, but the signaling state is not stable.")
        }
        
        guard isConfigurating else {
            throw WebRTCManagerError.critical("⚠️ Call startConfiguration() first before adding data channels!")
        }
        
        let dataChannel = peerConnection.dataChannel(
            forLabel: label,
            configuration: config ?? RTCDataChannelConfiguration()
        )
        
        if dataChannel == nil {
            print("⚠️ Failed to create a new data channel.")
        } else {
            print("ℹ️ New data channel created. Label: \(label)")
        }
        
        return dataChannel
    }
    
    func startConfiguration() async throws {
        
        guard let peerConnection else {
            throw WebRTCManagerError.critical(
                "⚠️ called startConfiguration, but peerConnection is nil; Did you call setup()?"
            )
        }
        
        guard [.connected, .completed].contains(peerConnection.iceConnectionState) else {
            throw WebRTCManagerError.critical("⚠️ Tried to start configuration before the call is running.")
        }
        
        isConfigurating = true
        isCommitConfigurationPostponed = false
    }
    
    func commitConfiguration() async throws {
        
        guard let peerConnection else {
            throw WebRTCManagerError.critical(
                "⚠️ called commitConfiguration, but peerConnection is nil; Did you call setup()?"
            )
        }
        
        guard [.connected, .completed].contains(peerConnection.iceConnectionState) else {
            throw WebRTCManagerError.critical("⚠️ Tried to commit configuration before the call is running.")
        }
        
        guard isConfigurating else {
            throw WebRTCManagerError.critical("⚠️ Tried to commit configuration before calling startConfiguration().")
        }
        
        guard peerConnection.signalingState == .stable else {
            print("ℹ️ Tried to commit configuration, but the signaling state is not stable; Postponing until stable.")
            isCommitConfigurationPostponed = true
            return
        }
        
        // stop configurating
        isConfigurating = false
        
        // reset postponed state
        isCommitConfigurationPostponed = false
        
        // trigger the re-negotiation offer
        peerConnectionShouldNegotiate(peerConnection)
    }
}

// MARK: - WebsocketConnectionDelegate

extension DefaultWebRTCManager: SignalingServerDelegate {
    
    func didReceiveSignal(
        _ signalData: Data,
        from remotePeerID: PeerID,
        isPolite: Bool
    ) async {
        Task { @WebRTCActor [weak self] in
            await self?.handleReceivedSignal(
                signalData,
                from: remotePeerID,
                isPolite: isPolite
            )
        }
    }
    
    func didReceiveICECandidate(_ candidateData: Data, from remotePeerID: PeerID) async {
        Task { @WebRTCActor in
            guard self.remotePeerID == remotePeerID else {
                return // signal is from another peer which we do not expect
            }
            
            await handleICECandidate(candidateData)
        }
    }
    
    func didReceiveEndCall(from remotePeerID: PeerID) async {
        guard self.remotePeerID == remotePeerID else {
            return // signal is from another peer which we do not expect
        }
        
        print("ℹ️ End Call message received.")
        delegate?.didReceiveEndCall()
    }
    
    func socketDidOpen() {
        Task { @WebRTCActor in
            guard
                let remotePeerID,
                let peerConnection
            else { return }
            
            do {
                print("ℹ️ Sending ICE restart offer…")
                try await sendOffer(
                    to: remotePeerID,
                    peerConnection: peerConnection,
                    iceRestart: true
                )
            } catch {
                print("⚠️ Error sending ICE restart offer.")
            }
        }
    }
    
    func socketDidClose() {
        // TODO
    }
}

// MARK: - WRKRTCPeerConnectionDelegate

extension DefaultWebRTCManager: WRKRTCPeerConnectionDelegate {
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("ℹ️ Signaling state: \(stateChanged)")
        Task { @WebRTCActor in
            if stateChanged == .stable, isCommitConfigurationPostponed {
                do {
                    try await commitConfiguration()
                } catch {
                    isConfigurating = false
                    isCommitConfigurationPostponed = false
                    print("❌ WebRTCManager - failed to commit configuration: \(error)")
                }
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didAdd stream: WRKMediaStream) {
        Task { @WebRTCActor in
            let audioTrack = stream.audioTracks.first
            let videoTrack = stream.videoTracks.first
            let hasAudio = audioTrack != nil
            let hasVideo = videoTrack != nil
            
            print("ℹ️ Remote peer did add media stream; audio: \(hasAudio), video: \(hasVideo)")
            
            setRemoteAudioTrack(audioTrack)
            setRemoteVideoTrack(videoTrack)
            
            if let videoTrack {
                delegate?.didAddRemoteVideoTrack(videoTrack)
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove stream: WRKMediaStream) {
        print("ℹ️ Remote peer did remove a media stream.")
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didAdd rtpReceiver: RtpReceiver) {
        print("ℹ️ Remote peer did add receiver.")
        Task { @WebRTCActor in
            guard let track = rtpReceiver.track as? RTCVideoTrack else { return }
            let remoteVideoTrack = WRKRTCVideoTrackImpl(track)
            self.remoteVideoTrack = remoteVideoTrack
            delegate?.didAddRemoteVideoTrack(remoteVideoTrack)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove rtpReceiver: RtpReceiver) {
        print("ℹ️ Remote peer did remove receiver.")
        Task { @WebRTCActor [self] in
            guard rtpReceiver.track?.kind == "video", let remoteVideoTrack else { return }
            self.remoteVideoTrack = nil
            delegate?.didRemoveRemoteVideoTrack(remoteVideoTrack)
        }
    }
    
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: WRKRTCPeerConnection) {
        Task { @WebRTCActor in
            await handleNegotiation(peerConnection)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @WebRTCActor in
            print("ℹ️ ICE connection state: \(newState)")
            switch newState {
            case .failed:
                delegate?.onError(.connectionFailed)
            case .connected, .completed, .new, .checking, .disconnected, .closed, .count:
                break
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Task { @WebRTCActor in
            print("ℹ️ ICE gathering state: \(newState)")
            switch newState {
            case .gathering:
                await processCachedCandidates()
            case .new, .complete:
                break
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        Task { @WebRTCActor in
            print("ℹ️ Peer connection state: \(newState)")
            switch newState {
            case .new, .disconnected, .failed, .closed, .connecting:
                break
            case .connected:
                callDidStart()
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didGenerate candidate: ICECandidate) {
        Task { @WebRTCActor in
            
            guard let remotePeerID else { return }
            
            do {
                let encoder = JSONEncoder()
                let candidateData = try encoder.encode(candidate)
                
                try await signalingServer.sendICECandidate(candidateData, to: remotePeerID)
            } catch {
                print("⚠️ Error sending ICE candidate - \(error)")
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove candidates: [ICECandidate]) {
        print("ℹ️ ICE candidates removed.")
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didOpen dataChannel: WRKDataChannel) {
        Task { [weak self] in
            print("ℹ️ New data channel opened - label: \(dataChannel.label)")
            await self?.delegate?.didReceiveDataChannel(dataChannel)
        }
    }
}

// MARK: - Private functions

private extension DefaultWebRTCManager {
    
    func connectToSignalingServer() async throws -> PeerID {
        
        // set delegate
        signalingServer.setDelegate(self)
        
        return try await signalingServer.connect()
    }
    
    func makePeerConnection() async throws -> WRKRTCPeerConnection {
        
        // if there is already a peer connection, just return that one
        if let peerConnection {
            return peerConnection
        }
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueFalse
            ],
            optionalConstraints: nil
        )
        
        let rtcConfig = RTCConfiguration()
        rtcConfig.sdpSemantics = .unifiedPlan
        rtcConfig.continualGatheringPolicy = .gatherContinually
        rtcConfig.iceCandidatePoolSize = 1
        rtcConfig.audioJitterBufferFastAccelerate = true
        rtcConfig.iceServers = config.iceServers.map {
            RTCIceServer(
                urlStrings: $0.urlStrings,
                username: $0.username,
                credential: $0.credential,
                tlsCertPolicy: $0.tlsCertPolicy,
                hostname: $0.hostname,
                tlsAlpnProtocols: $0.tlsAlpnProtocols,
                tlsEllipticCurves: $0.tlsEllipticCurves
            )
        }
        
        guard let peerConnection = factory.peerConnection(
            with: rtcConfig,
            constraints: constraints,
            delegate: self
        ) else {
            throw WebRTCManagerError.critical("Failed to create peer connection.")
        }
        
        return peerConnection
    }
    
    func addAudioTrack(to peerConnection: WRKRTCPeerConnection) async {
        
        // create audio track
        let audioSource = factory.audioSource(
            with: RTCMediaConstraints(
                mandatoryConstraints: [
                    "echoCancellation": "true",
                    "noiseSuppression": "true",
                    "autoGainControl": "true"
                ],
                optionalConstraints: nil
            )
        )
        let localAudioTrack = factory.audioTrack(with: audioSource, trackId: "localAudioTrack")
        
        // add audio track to the peer connection
        await peerConnection.add(localAudioTrack, streamIds: ["localStream"])
        
        // set audio encoding parameters
        bitrateAdjustor.setStartEncodingParameters(for: .audio, peerConnection: peerConnection)
        
        // save audio track
        self.localAudioTrack = localAudioTrack
        
        print("ℹ️ Successfully added audio track.")
    }
    
    func addVideoTrack(to peerConnection: WRKRTCPeerConnection) async {
        
        // create video track
        let videoSource = factory.videoSource()
        let localVideoTrack = factory.videoTrack(with: videoSource, trackId: "localVideoTrack")
        self.videoSource = videoSource
        
        // add video track to the peer connection
        localVideoSender = await peerConnection.add(localVideoTrack, streamIds: ["localStream"])
        
        // set video encoding parameters
        bitrateAdjustor.setStartEncodingParameters(for: .video, peerConnection: peerConnection)
        
        // save video track
        self.localVideoTrack = localVideoTrack
        
        // pass video track to the delegate
        delegate?.didAddLocalVideoTrack(localVideoTrack)
        
        print("ℹ️ Successfully added video track.")
    }
    
    func sendOffer(to peerID: PeerID, peerConnection: WRKRTCPeerConnection, iceRestart: Bool = false) async throws {
        
        // create an offer
        let offerConstraints = MediaConstraints(
            mandatoryConstraints: [
                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
            ],
            optionalConstraints: iceRestart ? [
                kRTCMediaConstraintsIceRestart: kRTCMediaConstraintsValueTrue
            ] : nil
        )
        
        let sdp = try await peerConnection.offer(for: offerConstraints)
        
        try await peerConnection.setLocalDescription(sdp)
        
        // encode the offer
        let encoder = JSONEncoder()
        let offerData = try encoder.encode(sdp)
        
        // send the offer
        try await signalingServer.sendSignal(offerData, to: peerID)
    }
    
    func sendAnswer(to peerID: PeerID, peerConnection: WRKRTCPeerConnection) async throws {
        
        let answerConstraints = MediaConstraints(
            mandatoryConstraints: [
                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
            ],
            optionalConstraints: nil
        )
        
        let answer = try await peerConnection.answer(for: answerConstraints)
        
        try await peerConnection.setLocalDescription(answer)
        
        let encoder = JSONEncoder()
        let answerData = try encoder.encode(answer)
        
        try await signalingServer.sendSignal(answerData, to: peerID)
        
        // Reset receivedOfferSDP after sending the answer
        self.receivedOfferSDP = nil
    }
    
    func handleICECandidate(_ candidateData: Data) async {
        
        guard let peerConnection else { return }
        
        guard
            peerConnection.iceGatheringState == .gathering,
            peerConnection.remoteDescription != nil
        else {
            await cachedICECandidates.store(candidateData)
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let candidate = try decoder.decode(ICECandidate.self, from: candidateData)
            
            try await peerConnection.add(candidate)
            
            print("ℹ️ Successfully evaluated ICE candidate.")
        } catch {
            print("⚠️ Error evaluating received ICE candidate - \(error)")
            
            if let candidateStr = String(data: candidateData, encoding: .utf8) {
                print(candidateStr)
            }
        }
    }
    
    func processCachedCandidates() async {
        
        guard 
            peerConnection?.iceGatheringState == .gathering,
            peerConnection?.remoteDescription != nil,
            !isProcessingCandidates
        else { return }
        
        isProcessingCandidates = true
        
        defer {
            isProcessingCandidates = false
        }
        
        print("ℹ️ Processing cached candidates…")
        
        while let candidateData = await cachedICECandidates.getNext() {
            await handleICECandidate(candidateData)
            
            // stop processing candidates when the gathering state changes
            guard 
                peerConnection?.iceGatheringState == .gathering,
                peerConnection?.remoteDescription != nil
            else {
                print("ℹ️ Aborted processing of cached candidates as the gathering state changed.")
                return
            }
        }
        
        print("ℹ️ Processing of cached candidate finished.")
    }
    
    func didReceiveOffer(
        _ sdp: RTCSessionDescription,
        peerConnection: WRKRTCPeerConnection,
        isPolite: Bool
    ) async throws {
        
        guard let remotePeerID else { return }
        
        isPreparingOffer = true
        
        defer {
            isPreparingOffer = false
        }
        
        let sdp = SessionDescription(from: sdp)
        
        // We did already generate a local offer while receiving an offer from our peer.
        if peerConnection.signalingState != .stable {
            print("ℹ️ Received a remote offer while we have already generated a local offer.")
            if isPolite {
                // We are the polite peer, so we drop our local offer and take the received one.
                // After that, we will immediately send an answer to our peer
                // as he called us and we called him, meaning we both want that call.
                print("ℹ️ Ignoring our local offer and answering to the remote offer as we are polite.")
                try await peerConnection.setLocalDescription(.rollback)
                try await peerConnection.setRemoteDescription(sdp)
                try await sendAnswer(to: remotePeerID, peerConnection: peerConnection)
            } else {
                // We are the impolite peer, so we keep our local offer,
                // ignore the received offer and wait for an answer from our peer.
                print("ℹ️ Ignoring the received offer as we are impolite.")
            }
            return
        }
        
        if receivedOfferSDP == nil, !callIsRunning {
            // incoming call
            self.receivedOfferSDP = sdp
            delegate?.didReceiveOffer(from: remotePeerID)
        } else {
            // ICE-restart or re-negotiation
            try await peerConnection.setRemoteDescription(sdp)
            try await sendAnswer(to: remotePeerID, peerConnection: peerConnection)
        }
    }
    
    func didReceiveAnswer(_ sdp: RTCSessionDescription, peerConnection: WRKRTCPeerConnection) async throws {
        
        let sdp = SessionDescription(from: sdp)
        
        // Is it the first answer? Otherwise it is an ICE-restart answer.
        let remoteDescription = peerConnection.remoteDescription
        let isFirstAnswer = remoteDescription == nil || remoteDescription?.type != .answer
        
        try await peerConnection.setRemoteDescription(sdp)
        
        if isFirstAnswer {
            await processCachedCandidates()
            delegate?.peerDidAcceptCallRequest()
            
            // check if we are already connected
            if [.connected, .completed].contains(peerConnection.iceConnectionState) {
                callDidStart()
            }
        }
    }
    
    func callDidStart() {
        callIsRunning = true
        delegate?.callDidStart()
    }
    
    func handleReceivedSignal(
        _ signalData: Data,
        from remotePeerID: PeerID,
        isPolite: Bool
    ) async {
        if self.remotePeerID == nil {
            self.remotePeerID = remotePeerID
        }
        
        guard self.remotePeerID == remotePeerID else {
            return // signal is from another peer which we do not expect
        }
        
        guard let peerConnection else { return }
        
        self.isPolite = isPolite
        
        do {
            let decoder = JSONDecoder()
            let sessionDescription = try decoder.decode(SessionDescription.self, from: signalData)
            let sdp = sessionDescription.toRTCSessionDescription()
            
            print("ℹ️ Did receive signal of type '\(sdp.type)'")
            
            switch sdp.type {
            case .offer:
                try await didReceiveOffer(
                    sdp,
                    peerConnection: peerConnection,
                    isPolite: isPolite
                )
            case .prAnswer:
                return // we do not send provisional offers/answers
            case .answer:
                try await didReceiveAnswer(
                    sdp,
                    peerConnection: peerConnection
                )
            case .rollback:
                return // we do not send rollbacks
            @unknown default:
                return
            }
            
        } catch {
            print("⚠️ didReceiveSignal failed - \(error)")
            
            if let signalStr = String(data: signalData, encoding: .utf8) {
                print(signalStr)
            }
        }
    }
    
    func setRemoteAudioTrack(_ remoteAudioTrack: WRKRTCAudioTrack?) {
        self.remoteAudioTrack = remoteAudioTrack
    }
    
    func setRemoteVideoTrack(_ remoteVideoTrack: WRKRTCVideoTrack?) {
        self.remoteVideoTrack = remoteVideoTrack
    }
    
    func handleNegotiation(_ peerConnection: WRKRTCPeerConnection) async {
        guard let remotePeerID else { return }
        
        print("ℹ️ Negotiation needed.")
        
        guard !isPreparingOffer else {
            print("ℹ️ Negotiation skipped as we are already preparing an offer / answer.")
            return
        }
        
        guard !isConfigurating else {
            print("ℹ️ Negotiation skipped, because we are currently configuring the peer connection.")
            return
        }
        
        isPreparingOffer = true
        
        defer {
            isPreparingOffer = false
        }
        
        do {
            try await peerConnection.setLocalDescription()
            guard let sdp = peerConnection.localDescription else { return }
            let encoder = JSONEncoder()
            let signal = try encoder.encode(SessionDescription(from: sdp))
            try await signalingServer.sendSignal(signal, to: remotePeerID)
            
            print("ℹ️ Negotiation sdp sent.")
        } catch {
            print("❌ Negotiation failed.")
        }
    }
}
