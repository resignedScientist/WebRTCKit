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
    
    /// We are accepting or denying a call request from another peer.
    case answeringCallRequest
    
    /// We are ending a call.
    case endingCall
    
    /// We are handling a critical error.
    case handlingError
    
    /// We are trying to establish a peer-to-peer connection
    case connecting
    
    static func canChangeState(from fromState: CallManagerState, to toState: CallManagerState) -> Bool {
        switch toState {
        case .idle:
            return [
                .endingCall,
                .handlingError
            ].contains(fromState)
        case .callIsRunning:
            return [.connecting].contains(fromState)
        case .receivingCallRequest:
            // we do not allow knocking for now
            return [.idle].contains(fromState)
        case .sendingCallRequest:
            return [.idle].contains(fromState)
        case .answeringCallRequest:
            return [.receivingCallRequest].contains(fromState)
        case .endingCall:
            return [
                .callIsRunning,
                .sendingCallRequest,
                .receivingCallRequest,
                .answeringCallRequest,
                .connecting
            ].contains(fromState)
        case .handlingError:
            return [
                .callIsRunning,
                .receivingCallRequest,
                .sendingCallRequest,
                .answeringCallRequest,
                .endingCall,
                .connecting
            ].contains(fromState)
        case .connecting:
            return [
                .sendingCallRequest,
                .answeringCallRequest
            ].contains(fromState)
        }
    }
}

protocol CallManagerStateHolder: Actor {
    
    func getState() async -> CallManagerState
    
    func changeState(to newState: CallManagerState) async throws
    
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
    ///
    /// - Parameter peerID: The ID of the peer which is calling.
    func didReceiveIncomingCall(from peerID: PeerID)
    
    /// Tells the delegate to show the local video stream.
    ///
    /// - Parameters:
    ///   - videoTrack: The local video track.
    func showLocalVideo(_ videoTrack: WRKRTCVideoTrack)
    
    /// Tells the delegate to show the remote video stream.
    ///
    /// - Parameters:
    ///   - videoTrack: The remote video track.
    func showRemoteVideo(_ videoTrack: WRKRTCVideoTrack)
    
    /// Tells the delegate that the remote video track has been removed.
    ///
    /// - Parameters:
    ///   - videoTrack: The remote video track.
    func remoteVideoTrackWasRemoved(_ videoTrack: WRKRTCVideoTrack)
    
    /// The call did start.
    func callDidStart()
    
    /// The call did end.
    func callDidEnd(withError error: CallManagerError?)
    
    /// Called when the peer created a new data channel.
    func didReceiveDataChannel(_ dataChannel: WRKDataChannel)
}

@WebRTCActor
protocol CallManager: Sendable {
    
    func setDelegate(_ delegate: CallManagerDelegate?)
    
    /// Called after the DIContainer was initialized and is ready to go.
    func setup() async
    
    /// Call another peer.
    ///
    /// - Parameter peerID: The ID of the peer to call.
    func sendCallRequest(to peerID: PeerID) async throws
    
    /// Answer an incoming call.
    ///
    /// - Parameter accept: True if we accept it, false if we decline it.
    func answerCallRequest(accept: Bool) async throws
    
    /// End a running call.
    func endCall() async throws
    
    /// End a call if it is running and disconnect from the signaling server.
    func disconnect() async throws
}
