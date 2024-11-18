import Foundation

public enum SignalingServerConnectionError: Error {
    case critical(_ message: String)
    case noInternetConnection
}

@WebRTCActor
public protocol SignalingServerDelegate: AnyObject, Sendable {
    
    /// We did receive a signal from another peer.
    ///
    /// - Parameters:
    ///   - signalData: The signal as data.
    ///   - remotePeerID: The ID of the sending peer.
    ///   - isPolite: Does this peer should act 'polite' as defined in the 'perfect negotiation' pattern?
    func didReceiveSignal(
        _ signalData: Data,
        from remotePeerID: PeerID,
        isPolite: Bool
    ) async
    
    /// We did receive an ICE candidate from another peer.
    ///
    /// - Parameters:
    ///   - candidateData: The ICE candidate as data.
    ///   - remotePeerID: The ID of the sending peer.
    func didReceiveICECandidate(_ candidateData: Data, from remotePeerID: PeerID) async
    
    /// We did receive an 'endCall' message from the other peer.
    /// That means that he hang up to end the call.
    ///
    /// - Parameter remotePeerID: The ID of the sending peer.
    func didReceiveEndCall(from remotePeerID: PeerID) async
    
    /// The websocket did open and is ready for sending / receiving messages.
    func socketDidOpen()
    
    /// The websocket did close.
    func socketDidClose()
}

@WebRTCActor
public protocol SignalingServerConnection: Sendable {
    
    /// Returns true if the connection is established / open.
    var isOpen: Bool { get }
    
    /// Set the delegate.
    func setDelegate(_ delegate: SignalingServerDelegate?)
    
    /// Establish a connection to the signaling server and receive the peer id.
    func connect() async throws -> PeerID
    
    /// Disconnect from the signaling server.
    func disconnect()
    
    /// Send a signal to the other peer through the signaling server.
    /// - Parameters:
    ///   - signal: The signal to send as data.
    ///   - destinationID: The ID of the other peer.
    func sendSignal(_ signal: Data, to destinationID: PeerID) async throws
    
    /// Send an ICE candidate to the other peer through the signaling server.
    /// - Parameters:
    ///   - candidate: The ICE candidate as data.
    ///   - destinationID: The ID of the other peer.
    func sendICECandidate(_ candidate: Data, to destinationID: PeerID) async throws
    
    /// Notify the other peer that we end the call.
    /// - Parameter destinationID: The ID of the other peer.
    func sendEndCall(to destinationID: PeerID) async throws
    
    /// The network connection has been re-established.
    func onConnectionSatisfied()
    
    /// The network connection was lost.
    func onConnectionUnsatisfied()
}
