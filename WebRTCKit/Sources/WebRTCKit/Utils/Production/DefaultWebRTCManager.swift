import WebRTC

final class DefaultWebRTCManager: NSObject, WebRTCManager {
    
    weak var delegate: WebRTCManagerDelegate?
    
    @Inject(\.callProvider) private var callProvider
    @Inject(\.signalingServer) private var signalingServer
    @Inject(\.config) private var config
    
    private let factory: WRKRTCPeerConnectionFactory
    private let rtcAudioSession: WRKRTCAudioSession
    private let bitrateAdjustor: BitrateAdjustor = BitrateAdjustorImpl()
    private let log = Logger(caller: "WebRTCManager")
    
    private var peerConnection: WRKRTCPeerConnection?
    private var videoCapturer: VideoCapturer?
    private var videoSource: RTCVideoSource?
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
    
    /// Are we currently processing cached ICE candidates?
    private var isProcessingCandidates = false
    
    /// Did we make changes that require a re-negotiation?
    private var configurationChanged = false
    
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
        
        // use manual mode to let our delegate handle the configuration,
        // activation & deactivation of the audio session.
        if !config.manualAudioMode {
            try await startAudioRecording()
        }
        
        // connect to signaling server
        let peerID = try await connectToSignalingServer()
        self.localPeerID = peerID
        
        // create peer connection
        let peerConnection = try await makePeerConnection()
        self.peerConnection = peerConnection
        
        return peerID
    }
    
    func startAudioRecording() async throws {
        guard let peerConnection else {
            throw WebRTCManagerError.critical("startAudioRecording failed; Missing peer connection. Did you call setup()?")
        }
        
        // add the audio track to the peer connection
        if let localAudioTrack {
            await peerConnection.add(localAudioTrack, streamIds: ["localStream"])
            delegate?.didAddLocalAudioTrack(localAudioTrack)
        } else {
            await addAudioTrack(to: peerConnection)
        }
    }
    
    func startVideoRecording(videoCapturer: VideoCapturer? = nil) async throws {
        guard let peerConnection else {
            throw WebRTCManagerError.critical("startVideoRecording failed; Missing peer connection. Did you call setup()?")
        }
        
        guard !isVideoRecording() else {
            log.error("Peer connection already contains a video track; we do not add a new one.")
            return
        }
        
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            log.error("Camera access has not been granted! Cannot add video stream.")
            return
        }
        
        guard let videoDevice = CaptureDevice(
            AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            )
        ) else {
            log.info("Did not find a capturing device. Skipping local video.")
            return
        }
        
        // use the existing video source or create a new one
        let videoSource = videoSource ?? factory.videoSource()
        
        // add the video track to the peer connection
        await addVideoTrack(to: peerConnection, videoSource: videoSource)
        
        // save the video source
        self.videoSource = videoSource
        
        if let videoCapturer { // use custom input
            videoCapturer.delegate = videoSource
            self.videoCapturer = videoCapturer
            log.info("Using custom video capturer as input.")
        } else {
            
            // use default front camera as input
            
            guard
                let format = videoDevice.formats.last(where: { format in
                    let resolution = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    return resolution.height <= 480
                })
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
            
            log.info("Video capturing started using default front camera as input.")
        }
        
        // start bitrate adjustor if we are already connected
        if peerConnection.connectionState == .connected {
            bitrateAdjustor.start(for: .video, peerConnection: peerConnection)
        }
    }
    
    func stopVideoRecording() async {
        
        // stop video capturer
        async let stopVideoCapturer: Void? = videoCapturer?.stop()
        
        // remove video track
        if let peerConnection, let localVideoSender {
            await peerConnection.removeTrack(localVideoSender)
            self.localVideoSender = nil
            localVideoTrack = nil
            log.info("Local video track removed.")
        } else {
            log.error("Video sender is nil. No video track to remove.")
        }
        
        await stopVideoCapturer
        videoCapturer = nil
        
        // stop bitrate adjustor for video
        await bitrateAdjustor.stop(for: .video)
        
        log.info("Video recording stopped.")
    }
    
    func isVideoRecording() -> Bool {
        peerConnection?.senders.contains(where: { $0.track is RTCVideoTrack }) == true
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
        
        log.info("Stopping video call…")
        
        // clear messages that might be still in the queue
        signalingServer.clearMessageQueue()
        
        // send end call message to our peer
        if let remotePeerID {
            do {
                try await signalingServer.sendEndCall(to: remotePeerID)
            } catch {
                log.error("Failed to send 'end call' message to our peer.")
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
        if peerConnection.connectionState == .connected {
            delegate?.callDidStart()
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
        
        // we need to send a negotiation sdp in the case of channel opening while calling
        configurationChanged = true
        
        let dataChannel = peerConnection.dataChannel(
            forLabel: label,
            configuration: config ?? RTCDataChannelConfiguration()
        )
        
        if dataChannel == nil {
            log.error("Failed to create a new data channel.")
        } else {
            log.info("New data channel created. Label: \(label)")
        }
        
        return dataChannel
    }
    
    func startConfiguration() async throws {
        
        guard let peerConnection else {
            throw WebRTCManagerError.critical(
                "⚠️ called startConfiguration, but peerConnection is nil; Did you call setup()?"
            )
        }
        
        guard peerConnection.connectionState == .connected else {
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
        
        guard peerConnection.connectionState == .connected else {
            throw WebRTCManagerError.critical("⚠️ Tried to commit configuration before the call is running.")
        }
        
        guard isConfigurating else {
            throw WebRTCManagerError.critical("⚠️ Tried to commit configuration before calling startConfiguration().")
        }
        
        guard peerConnection.signalingState == .stable else {
            log.info("Tried to commit configuration, but the signaling state is not stable; Postponing until stable.")
            isCommitConfigurationPostponed = true
            return
        }
        
        // stop configurating
        isConfigurating = false
        
        // reset postponed state
        isCommitConfigurationPostponed = false
        
        // trigger the re-negotiation offer
        await handleNegotiation(peerConnection)
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
        
        log.info("End Call message received.")
        delegate?.didReceiveEndCall()
    }
    
    func socketDidOpen() {
        Task { @WebRTCActor in
            guard
                let remotePeerID,
                let peerConnection
            else { return }
            
            do {
                log.info("Sending ICE restart offer…")
                try await sendOffer(
                    to: remotePeerID,
                    peerConnection: peerConnection,
                    iceRestart: true
                )
            } catch {
                log.error("Error sending ICE restart offer.")
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
        log.info("Signaling state: \(stateChanged)")
        Task { @WebRTCActor in
            if stateChanged == .stable, isCommitConfigurationPostponed {
                isConfigurating = true
                defer {
                    isConfigurating = false
                    isCommitConfigurationPostponed = false
                }
                do {
                    try await commitConfiguration()
                } catch {
                    log.fault("Failed to run postponed commit configuration: \(error)")
                }
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didAdd rtpReceiver: RtpReceiver) {
        Task { @WebRTCActor in
            
            // video
            if let videoTrack = rtpReceiver.track as? RTCVideoTrack {
                let remoteVideoTrack = WRKRTCVideoTrackImpl(videoTrack, source: .remote)
                self.remoteVideoTrack = remoteVideoTrack
                delegate?.didAddRemoteVideoTrack(remoteVideoTrack)
                log.info("Remote peer did add receiver for video.")
            }
            
            // audio
            if let audioTrack = rtpReceiver.track as? RTCAudioTrack {
                let remoteAudioTrack = WRKRTCAudioTrackImpl(audioTrack, source: .remote)
                self.remoteAudioTrack = remoteAudioTrack
                delegate?.didAddRemoteAudioTrack(remoteAudioTrack)
                log.info("Remote peer did add receiver for audio.")
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove rtpReceiver: RtpReceiver) {
        Task { @WebRTCActor [self] in
            
            // video
            if rtpReceiver.track is RTCVideoTrack, let remoteVideoTrack {
                self.remoteVideoTrack = nil
                delegate?.didRemoveRemoteVideoTrack(remoteVideoTrack)
                log.info("Remote peer did remove receiver for video.")
            }
            
            // audio
            if rtpReceiver.track is RTCAudioTrack, let remoteAudioTrack {
                self.remoteAudioTrack = nil
                delegate?.didRemoveRemoteAudioTrack(remoteAudioTrack)
                log.info("Remote peer did remove receiver for audio.")
            }
        }
    }
    
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: WRKRTCPeerConnection) {
        Task { @WebRTCActor in
//            configurationChanged = true
            await handleNegotiation(peerConnection)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @WebRTCActor in
            log.info("ICE connection state: \(newState)")
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
            log.info("ICE gathering state: \(newState)")
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
            log.info("Peer connection state: \(newState)")
            switch newState {
            case .new, .connecting:
                break
            case .connected:
                delegate?.callDidStart()
                bitrateAdjustor.start(for: .audio, peerConnection: peerConnection)
                bitrateAdjustor.start(for: .video, peerConnection: peerConnection)
            case .disconnected:
                delegate?.didLosePeerConnection()
                await bitrateAdjustor.stop(for: .audio)
                await bitrateAdjustor.stop(for: .video)
            case .closed, .failed:
                delegate?.callDidEnd()
                await bitrateAdjustor.stop(for: .audio)
                await bitrateAdjustor.stop(for: .video)
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
                log.error("Error sending ICE candidate - \(error)")
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove candidates: [ICECandidate]) {
        log.info("ICE candidates removed.")
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didOpen dataChannel: WRKDataChannel) {
        Task { @WebRTCActor in
            log.info("New data channel opened - label: \(dataChannel.label)")
            delegate?.didReceiveDataChannel(dataChannel)
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
                    "googEchoCancellation": kRTCMediaConstraintsValueTrue,
                    "googNoiseSuppression": kRTCMediaConstraintsValueTrue,
                    "googAutoGainControl": kRTCMediaConstraintsValueTrue
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
        
        // inform our delegate
        delegate?.didAddLocalAudioTrack(localAudioTrack)
        
        log.info("Successfully added audio track.")
    }
    
    func addVideoTrack(to peerConnection: WRKRTCPeerConnection, videoSource: RTCVideoSource) async {
        
        // use the existing video track if it exists
        if let localVideoTrack {
            localVideoSender = await peerConnection.add(localVideoTrack, streamIds: ["localStream"])
            return
        }
        
        // create video track
        let localVideoTrack = factory.videoTrack(with: videoSource, trackId: "localVideoTrack")
        
        // add video track to the peer connection
        localVideoSender = await peerConnection.add(localVideoTrack, streamIds: ["localStream"])
        
        // set video encoding parameters
        bitrateAdjustor.setStartEncodingParameters(for: .video, peerConnection: peerConnection)
        
        // save video track
        self.localVideoTrack = localVideoTrack
        
        // pass video track to the delegate
        delegate?.didAddLocalVideoTrack(localVideoTrack)
        
        log.info("Successfully added video track.")
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
            
            log.info("Successfully evaluated ICE candidate.")
        } catch {
            log.error("Error evaluating received ICE candidate - \(error)")
            
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
        
        log.info("Processing cached candidates…")
        
        while let candidateData = await cachedICECandidates.getNext() {
            await handleICECandidate(candidateData)
            
            // stop processing candidates when the gathering state changes
            guard 
                peerConnection?.iceGatheringState == .gathering,
                peerConnection?.remoteDescription != nil
            else {
                log.info("Aborted processing of cached candidates as the gathering state changed.")
                return
            }
        }
        
        log.info("Processing of cached candidate finished.")
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
            log.info("Received a remote offer while we have already generated a local offer.")
            if isPolite {
                
                // We are the polite peer, so we drop our local offer and take the received one.
                // After that, we will immediately send an answer to our peer
                // as he called us and we called him, meaning we both want that call.
                log.info("Ignoring our local offer and answering to the remote offer as we are polite.")
                try await peerConnection.setLocalDescription(.rollback)
                try await peerConnection.setRemoteDescription(sdp)
                try await sendAnswer(to: remotePeerID, peerConnection: peerConnection)
                
                if peerConnection.connectionState == .connected {
                    log.info("The call is running which means both clients sent re-negotiation sdp; negotiating again…")
                    configurationChanged = true
                    await handleNegotiation(peerConnection)
                }
            } else {
                // We are the impolite peer, so we keep our local offer,
                // ignore the received offer and wait for an answer from our peer.
                log.info("Ignoring the received offer as we are impolite.")
            }
            return
        }
        
        if peerConnection.connectionState != .connected {
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
            if peerConnection.connectionState == .connected {
                delegate?.callDidStart()
            }
        }
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
            
            log.info("Did receive signal of type '\(sdp.type)'")
            
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
            log.error("Handling received signal failed - \(error)")
            
            if let signalStr = String(data: signalData, encoding: .utf8) {
                print(signalStr)
            }
        }
    }
    
    func handleNegotiation(_ peerConnection: WRKRTCPeerConnection) async {
        guard let remotePeerID else { return }
        
        log.info("Starting negotiation…")
        
        guard !isPreparingOffer else {
            log.info("Negotiation skipped as we are already preparing an offer / answer.")
            return
        }
        
        guard !isConfigurating else {
            log.info("Negotiation skipped, because we are currently configuring the peer connection.")
            return
        }
        
        guard configurationChanged else {
            log.info("Negotiation skipped, because the configuration did not change.")
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
            configurationChanged = false
            
            log.info("Negotiation sdp sent.")
        } catch {
            log.error("Negotiation failed - \(error)")
        }
    }
}
