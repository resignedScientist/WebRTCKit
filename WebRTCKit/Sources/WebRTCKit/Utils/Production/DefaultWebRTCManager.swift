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
    private var videoCapturer: RTCVideoCapturer?
    private var videoSource: WRKRTCVideoSource?
    private var remoteAudioTrack: WRKRTCAudioTrack?
    private var remoteVideoTrack: WRKRTCVideoTrack?
    private var localAudioTrack: WRKRTCAudioTrack?
    private var localVideoTrack: WRKRTCVideoTrack?
    private var localPeerID: PeerID?
    private var remotePeerID: PeerID?
    
    /// Cache of received ICE candidates that are processed when our peerConnection is ready.
    private var cachedICECandidates = ICECandidateCache()
    
    /// The offer SDP coming from the other peer that is cached until the user answers the call.
    private var receivedOfferSDP: RTCSessionDescription?
    
    /// Does this peer should act 'polite' as defined in the 'perfect negotiation' pattern?
    private var isPolite = false
    
    /// Does this peer currently prepare an offer?
    private var isPreparingOffer = false
    
    /// Is the configuration of data channels and other parameters running?
    private var isConfigurating = false
    
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
        
        // add the media stream to the peer connection
        if let localAudioTrack, let localVideoTrack {
            peerConnection.add(localAudioTrack, streamIds: ["localStream"])
            peerConnection.add(localVideoTrack, streamIds: ["localStream"])
        } else {
            await addMediaStream(to: peerConnection)
        }
        
        return peerID
    }
    
    func startRecording(videoCapturer: RTCVideoCapturer? = nil) async throws {
        guard peerConnection != nil else {
            throw WebRTCManagerError.critical("⚠️ startRecording failed; Missing peer connection. Did you call setup()?")
        }
        
        let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        )
        
        if videoDevice == nil {
            
            // We do not have a capturing device,
            // so we are assuming, we are running on the simulator.
            // -> We use an example video as input
            
            print("ℹ️ Did not find a capturing device. Using example video as input.")
            
            guard let videoSource else { return }
            
            let videoCapturer = PreviewVideoCapturer(delegate: videoSource)
            
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
            try videoDevice.lockForConfiguration()
            videoDevice.activeFormat = format
            videoDevice.unlockForConfiguration()
            
            // setup video capturer
            let videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
            self.videoCapturer = videoCapturer
            
            // start capturing video
            try await videoCapturer.startCapture(
                with: videoDevice,
                format: videoDevice.activeFormat,
                fps: 30
            )
        }
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
        bitrateAdjustor.stop()
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
        
        guard peerConnection.signalingState == .stable else {
            throw WebRTCManagerError.critical("⚠️ Tried to start configuration, but the signaling state is not stable.")
        }
        
        isConfigurating = true
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
        
        guard peerConnection.signalingState == .stable else {
            throw WebRTCManagerError.critical("⚠️ Tried to commit configuration, but the signaling state is not stable.")
        }
        
        guard isConfigurating else {
            throw WebRTCManagerError.critical("⚠️ Tried to commit configuration before calling startConfiguration().")
        }
        
        // stop configurating
        isConfigurating = false
        
        // trigger the re-negotiation offer
        peerConnectionShouldNegotiate(peerConnection)
    }
}

// MARK: - WebsocketConnectionDelegate

extension DefaultWebRTCManager: SignalingServerDelegate {
    
    nonisolated func didReceiveSignal(
        _ signalData: Data,
        from remotePeerID: PeerID,
        isPolite: Bool
    ) async {
        Task { [weak self] in
            await self?.handleReceivedSignal(
                signalData,
                from: remotePeerID,
                isPolite: isPolite
            )
        }
    }
    
    nonisolated func didReceiveICECandidate(_ candidateData: Data, from remotePeerID: PeerID) async {
        Task { [weak self] in
            guard await self?.remotePeerID == remotePeerID else {
                return // signal is from another peer which we do not expect
            }
            
            await self?.handleICECandidate(candidateData)
        }
    }
    
    nonisolated func didReceiveEndCall(from remotePeerID: PeerID) async {
        Task { [weak self] in
            guard await self?.remotePeerID == remotePeerID else {
                return // signal is from another peer which we do not expect
            }
            
            print("ℹ️ End Call message received.")
            await self?.delegate?.didReceiveEndCall()
        }
    }
    
    nonisolated func socketDidOpen() {
        Task { [weak self] in
            guard
                let remotePeerID = await self?.remotePeerID,
                let peerConnection = await self?.peerConnection
            else { return }
            
            do {
                print("ℹ️ Sending ICE restart offer…")
                try await self?.sendOffer(
                    to: remotePeerID,
                    peerConnection: peerConnection,
                    iceRestart: true
                )
            } catch {
                print("⚠️ Error sending ICE restart offer.")
            }
        }
    }
    
    nonisolated func socketDidClose() {
        // TODO
    }
}

// MARK: - WRKRTCPeerConnectionDelegate

extension DefaultWebRTCManager: WRKRTCPeerConnectionDelegate {
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("ℹ️ Signaling state: \(stateChanged)")
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didAdd stream: WRKMediaStream) {
        Task { [weak self] in
            let audioTrack = stream.audioTracks.first
            let videoTrack = stream.videoTracks.first
            let hasAudio = audioTrack != nil
            let hasVideo = videoTrack != nil
            
            print("ℹ️ Remote peer did add media stream; audio: \(hasAudio), video: \(hasVideo)")
            
            await self?.setRemoteAudioTrack(audioTrack)
            await self?.setRemoteVideoTrack(videoTrack)
            
            if let videoTrack {
                await self?.delegate?.didAddRemoteVideoTrack(videoTrack)
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove stream: WRKMediaStream) {
        print("ℹ️ Remote peer did remove a media stream.")
    }
    
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: WRKRTCPeerConnection) {
        Task { [weak self] in
            await self?.handleNegotiation(peerConnection)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { [weak self] in
            print("ℹ️ ICE connection state: \(newState)")
            switch newState {
            case .failed:
                await self?.delegate?.onError(.connectionFailed)
            case .connected, .completed, .new, .checking, .disconnected, .closed, .count:
                break
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Task { [weak self] in
            print("ℹ️ ICE gathering state: \(newState)")
            switch newState {
            case .gathering:
                await self?.processCachedCandidates()
            case .new, .complete:
                break
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
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
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Task { [weak self] in
            
            guard let remotePeerID = await self?.remotePeerID else { return }
            
            do {
                let encoder = JSONEncoder()
                let candidateData = try encoder.encode(ICECandidate(from: candidate))
                
                try await self?.signalingServer.sendICECandidate(candidateData, to: remotePeerID)
            } catch {
                print("⚠️ Error sending ICE candidate - \(error)")
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("ℹ️ ICE candidates removed.")
    }
    
    nonisolated func peerConnection(_ peerConnection: WRKRTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Task { [weak self] in
            print("ℹ️ New data channel opened - label: \(dataChannel.label)")
            await self?.delegate?.didReceiveDataChannel(
                WRKDataChannelImpl(dataChannel)
            )
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
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
            ],
            optionalConstraints: nil
        )
        
        let rtcConfig = RTCConfiguration()
        rtcConfig.sdpSemantics = .unifiedPlan
        rtcConfig.continualGatheringPolicy = .gatherContinually
        rtcConfig.iceCandidatePoolSize = 1
        rtcConfig.audioJitterBufferFastAccelerate = true
        rtcConfig.iceServers = config.iceServers
        
        guard let peerConnection = factory.peerConnection(
            with: rtcConfig,
            constraints: constraints,
            delegate: self
        ) else {
            throw WebRTCManagerError.critical("Failed to create peer connection.")
        }
        
        bitrateAdjustor.start(peerConnection: peerConnection)
        
        return peerConnection
    }
    
    func addMediaStream(to peerConnection: WRKRTCPeerConnection) async {
        
        // video
        let videoSource = factory.videoSource()
        let localVideoTrack = factory.videoTrack(with: videoSource, trackId: "localVideoTrack")
        self.videoSource = videoSource
        
        // audio
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
        
        // add tracks to the peer connection
        peerConnection.add(localVideoTrack, streamIds: ["localStream"])
        peerConnection.add(localAudioTrack, streamIds: ["localStream"])
        
        // set audio & video encoding parameters
        bitrateAdjustor.setStartEncodingParameters(peerConnection: peerConnection)
        
        // save media tracks
        self.localVideoTrack = localVideoTrack
        self.localAudioTrack = localAudioTrack
        
        print("ℹ️ Successfully started capturing audio/video.")
        
        delegate?.didAddLocalVideoTrack(localVideoTrack)
    }
    
    func sendOffer(to peerID: PeerID, peerConnection: WRKRTCPeerConnection, iceRestart: Bool = false) async throws {
        
        // create an offer
        let offerConstraints = RTCMediaConstraints(
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
        let offerData = try encoder.encode(SessionDescription(from: sdp))
        
        // send the offer
        try await signalingServer.sendSignal(offerData, to: peerID)
    }
    
    func sendAnswer(to peerID: PeerID, peerConnection: WRKRTCPeerConnection) async throws {
        
        let answerConstraints = RTCMediaConstraints(
            mandatoryConstraints: [
                kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
            ],
            optionalConstraints: nil
        )
        
        let answer = try await peerConnection.answer(for: answerConstraints)
        
        try await peerConnection.setLocalDescription(answer)
        
        let encoder = JSONEncoder()
        let answerData = try encoder.encode(SessionDescription(from: answer))
        
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
            
            try await peerConnection.add(candidate.toRTCIceCandidate())
            
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
