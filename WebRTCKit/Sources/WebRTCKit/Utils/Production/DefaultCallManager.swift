import WebRTC
import CallKit

final class DefaultCallManager: CallManager {
    
    private weak var delegate: CallManagerDelegate?
    
    @Inject(\.callProvider) private var callProvider
    @Inject(\.webRTCManager) private var webRTCManager
    @Inject(\.signalingServer) private var signalingServer
    @Inject(\.config) private var config
    
    private let stateHolder: CallManagerStateHolder
    private let log = Logger(caller: "CallManager")
    
    private var connectionTimeout: Task<Void, Never>?
    private var state: CallManagerState = .idle
    
    init(stateHolder: CallManagerStateHolder = CallManagerStateHolderImpl(initialState: .idle)) {
        self.stateHolder = stateHolder
    }
    
    func setDelegate(_ delegate: CallManagerDelegate?) {
        self.delegate = delegate
    }
    
    func setup() async {
        webRTCManager.setDelegate(self)
    }
    
    func sendCallRequest(to peerID: PeerID) async throws {
        log.info("Sending call request…")
        try await stateHolder.changeState(to: .sendingCallRequest)
        try await callProvider.startOutgoingCall(
            uuid: UUID(),
            handle: peerID,
            hasVideo: true
        )
    }
    
    func answerCallRequest(accept: Bool) async throws {
        log.info("Answering call request (accept = \(accept))…")
        try await stateHolder.changeState(to: .answeringCallRequest)
        
        if accept {
            try await callProvider.acceptIncomingCall()
        } else {
            try await endCall()
        }
    }
    
    func endCall() async throws {
        log.info("Ending call…")
        try await stateHolder.changeState(to: .endingCall)
        try await callProvider.endCall()
        stopConnectionTimeout()
    }
    
    func disconnect() async throws {
        log.info("Disconnecting…")
        
        // end call if it is running
        if await stateHolder.canChangeState(to: .endingCall) {
            try await endCall()
        } else {
            await webRTCManager.disconnect()
        }
        
        // disconnect from the signaling server
        signalingServer.disconnect()
    }
}

// MARK: - WebRTCManagerDelegate

extension DefaultCallManager: WebRTCManagerDelegate {
    
    func didAddLocalVideoTrack(_ videoTrack: WRKRTCVideoTrack) {
        delegate?.showLocalVideo(videoTrack)
    }
    
    func didAddRemoteVideoTrack(_ videoTrack: any WRKRTCVideoTrack) {
        delegate?.showRemoteVideo(videoTrack)
    }
    
    func didRemoveRemoteVideoTrack(_ videoTrack: any WRKRTCVideoTrack) {
        delegate?.remoteVideoTrackWasRemoved(videoTrack)
    }
    
    func didReceiveEndCall() {
        Task { @WebRTCActor in
            
            // this is the end call confirmation; we can ignore it
            guard await stateHolder.getState() != .idle else { return }
            
            do {
                try await stateHolder.changeState(to: .endingCall)
                try await callProvider.endCall()
            } catch {
                log.error("DidReceiveEndCall failed - \(error)")
            }
        }
    }
    
    func callDidEnd() {
        Task { @WebRTCActor in
            try await stateHolder.changeState(to: .idle)
            delegate?.callDidEnd(withError: nil)
        }
    }
    
    func didReceiveOffer(from peerID: PeerID) {
        Task { @WebRTCActor in
            do {
                try await stateHolder.changeState(to: .receivingCallRequest)
                try await callProvider.reportIncomingCall(
                    uuid: UUID(),
                    handle: peerID,
                    hasVideo: true
                )
                delegate?.didReceiveIncomingCall(from: peerID)
            } catch let error as CXErrorCodeIncomingCallError {
                log.error("DidReceiveOffer failed - \(error.code)")
            } catch {
                log.error("DidReceiveOffer failed - \(error)")
            }
        }
    }
    
    func onError(_ error: WebRTCManagerError) {
        Task { @WebRTCActor in
            do {
                try await stateHolder.changeState(to: .handlingError)
                try await callProvider.endCall()
                try await stateHolder.changeState(to: .idle)
                delegate?.callDidEnd(withError: .webRTCManagerError(error))
            } catch {
                log.error("OnError failed - \(error)")
            }
        }
    }
    
    func callDidStart() {
        Task { @WebRTCActor in
            
            // skip if call is already running
            guard await stateHolder.getState() != .callIsRunning else { return }
            
            do {
                try await stateHolder.changeState(to: .callIsRunning)
                delegate?.callDidStart()
                stopConnectionTimeout()
            } catch {
                log.fault("Failed to change state to 'callIsRunning' - \(error)")
            }
        }
    }
    
    func peerDidAcceptCallRequest() {
        Task { @WebRTCActor in
            let state = await stateHolder.getState()
            
            // we are already connected
            guard state != .callIsRunning else { return }
            
            do {
                try await stateHolder.changeState(to: .connecting)
                startConnectionTimeout()
            } catch {
                log.fault("Failed to change state to 'connecting' - \(error)")
            }
        }
    }
    
    func didAcceptCallRequest() {
        Task { @WebRTCActor in
            do {
                try await stateHolder.changeState(to: .connecting)
                startConnectionTimeout()
            } catch {
                log.fault("Failed to change state to 'connecting' - \(error)")
            }
        }
    }
    
    func didReceiveDataChannel(_ dataChannel: WRKDataChannel) {
        delegate?.didReceiveDataChannel(dataChannel)
    }
}

// MARK: - Private functions

private extension DefaultCallManager {
    
    func startConnectionTimeout() {
        connectionTimeout = Task { @WebRTCActor [weak self] in
            await self?.onConnectionTimeout()
        }
    }
    
    func stopConnectionTimeout() {
        connectionTimeout?.cancel()
        connectionTimeout = nil
    }
    
    func onConnectionTimeout() async {
        
        defer {
            stopConnectionTimeout()
        }
        
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000 * config.connectionTimeout)
            if !Task.isCancelled {
                log.error("Connection timeout.")
                
                // If state is idle, the peers connection timeout was triggered first.
                if await stateHolder.getState() != .idle {
                    delegate?.callDidEnd(withError: CallManagerError.connectionTimeout)
                    try await endCall()
                }
            }
        } catch {
            if !(error is CancellationError) {
                log.error("Error aborting connecting call - \(error)")
            }
        }
    }
}
