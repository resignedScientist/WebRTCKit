import Foundation
import WebRTC

public enum CallManagerState: Equatable, Sendable {
    
    /// Nothing is going on and we are waiting for input.
    case idle
    
    /// A call with another peer is running.
    case callIsRunning
    
    /// We are receiving a call request from another peer.
    case receivingCallRequest
    
    /// We are calling another peer.
    case sendingCallRequest
    
    /// We are ending a call.
    case endingCall
    
    /// We are trying to establish a peer-to-peer connection
    case connecting
    
    /// Determines if the state can change from one state to another.
    /// - Parameters:
    ///   - fromState: The current state.
    ///   - toState: The state to change to.
    /// - Returns: True if the state can be changed to the specified state.
    static func canChangeState(from fromState: CallManagerState, to toState: CallManagerState) -> Bool {
        switch toState {
        case .idle:
            return [.endingCall].contains(fromState)
        case .callIsRunning:
            return [.connecting].contains(fromState)
        case .receivingCallRequest:
            // we do not allow knocking for now
            return [.idle].contains(fromState)
        case .sendingCallRequest:
            return [.idle].contains(fromState)
        case .endingCall:
            return [
                .callIsRunning,
                .sendingCallRequest,
                .receivingCallRequest,
                .connecting
            ].contains(fromState)
        case .connecting:
            return [
                .sendingCallRequest,
                .receivingCallRequest,
                .callIsRunning
            ].contains(fromState)
        }
    }
}

/// Protocol to hold and manage call states.
protocol CallManagerStateHolder: Actor {
    
    /// Gets the current state.
    /// - Returns: The current call manager state.
    func getState() async -> CallManagerState
    
    /// Changes the current state to a new state.
    /// - Parameter newState: The new state to change to.
    /// - Throws: An error if the state transition is not allowed.
    func changeState(to newState: CallManagerState) async throws
    
    /// Determines if the state can change to the specified new state.
    /// - Parameter newState: The new state to verify.
    /// - Returns: True if the state can change.
    func canChangeState(to newState: CallManagerState) async -> Bool
}

actor CallManagerStateHolderImpl: CallManagerStateHolder {
    
    private var state: CallManagerState
    
    private let log = Logger(caller: "CallManagerStateHolder")
    
    init(initialState state: CallManagerState) {
        self.state = state
    }
    
    func getState() async -> CallManagerState { state }
    
    func changeState(to newState: CallManagerState) throws {
        
        guard state != newState else { return } // no change
        
        guard CallManagerState.canChangeState(from: state, to: newState) else {
            throw CallManagerError.invalidStateChange(
                fromState: state,
                toState: newState
            )
        }
        
        log.info("CallState changed from \(state) to \(newState)")
        
        state = newState
    }
    
    func canChangeState(to newState: CallManagerState) -> Bool {
        CallManagerState.canChangeState(from: state, to: newState)
    }
}

public enum CallManagerError: LocalizedError, Equatable {
    case connectionTimeout
    case invalidStateChange(
        fromState: CallManagerState,
        toState: CallManagerState
    )
    case webRTCManagerError(_ error: WebRTCManagerError)
    
    public var errorDescription: String? {
        switch self {
        case .connectionTimeout:
            return "Connection Timeout"
        case let .invalidStateChange(fromState, toState):
            return "Cannot change from state \(fromState) to \(toState)"
        case let .webRTCManagerError(error):
            return error.localizedDescription
        }
    }
}

public protocol CallManagerDelegate: AnyObject, Sendable {
    
    /// We received an incoming call.
    /// - Parameter peerID: The ID of the peer which is calling.
    func didReceiveIncomingCall(from peerID: PeerID)
    
    /// We did add a local video track to the stream.
    ///
    /// The view can show the local video using the `WebRTCVideoView`.
    /// - Parameter videoTrack: The local video track.
    func didAddLocalVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// Our remote peer did add a video track to the stream.
    ///
    /// The view can show the remote video using the `WebRTCVideoView`.
    /// - Parameter videoTrack: The remote video track.
    func didAddRemoteVideoTrack(_ videoTrack: WRKRTCVideoTrack)
    
    /// We did add a local audio track to the session.
    ///
    /// It will be sent automatically. You can use this track instance to mute it for example.
    /// - Parameter audioTrack: The local audio track.
    func didAddLocalAudioTrack(_ audioTrack: WRKRTCAudioTrack)
    
    /// Our remote peer did add an audio track to the session.
    ///
    /// It will be played automatically. You can use this track instance to mute it for example.
    /// - Parameter audioTrack: The remote audio track.
    func didAddRemoteAudioTrack(_ audioTrack: WRKRTCAudioTrack)
    
    /// Tells the delegate that the remote video track has been removed.
    /// - Parameter videoTrack: The remote video track.
    func remoteVideoTrackWasRemoved(_ videoTrack: WRKRTCVideoTrack)
    
    /// The call did start.
    func callDidStart()
    
    /// The call did end.
    /// - Parameter error: Error if the call ended with an error.
    func callDidEnd(withError error: CallManagerError?)
    
    /// Called when the peer created a new data channel.
    /// - Parameter dataChannel: The new data channel.
    func didReceiveDataChannel(_ dataChannel: WRKDataChannel)
    
    /// Called when we lost the connection to our peer.
    func didLosePeerConnection()
}

extension CallManagerDelegate {
    
    func didAddLocalAudioTrack(_ audioTrack: WRKRTCAudioTrack) {}
    
    func didAddRemoteAudioTrack(_ audioTrack: WRKRTCAudioTrack) {}
    
    func remoteVideoTrackWasRemoved(_ videoTrack: WRKRTCVideoTrack) {}
}

@WebRTCActor
protocol CallManager: Sendable {
    
    func getState() async -> CallManagerState
    
    /// Sets the delegate to handle call events.
    /// - Parameter delegate: The delegate to handle call events.
    func setDelegate(_ delegate: CallManagerDelegate?)
    
    /// Called after the DIContainer was initialized and is ready to go.
    func setup() async
    
    /// Call another peer.
    /// - Parameter peerID: The ID of the peer to call.
    /// - Throws: An error if the call request fails.
    func sendCallRequest(to peerID: PeerID) async throws
    
    /// Answer an incoming call.
    /// - Parameter accept: True if we accept it, false if we decline it.
    /// - Throws: An error if answering the call request fails.
    func answerCallRequest(accept: Bool) async throws
    
    /// End a running call.
    /// - Throws: An error if ending the call fails.
    func endCall() async throws
    
    /// End a call if it is running and disconnect from the signaling server.
    /// - Throws: An error if disconnecting fails.
    func disconnect() async throws
}
