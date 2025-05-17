import Foundation

final class PreviewSignalingServerConnection: SignalingServerConnection {
    
    var isOpen = false
    
    func setDelegate(_ delegate: SignalingServerDelegate?) {
        
    }
    
    func connect() async throws -> PeerID {
        "0000"
    }
    
    func disconnect() {
        
    }
    
    func sendSignal(_ signal: Data, to destinationID: PeerID) async throws {
        
    }
    
    func sendICECandidate(_ candidate: Data, to destinationID: PeerID) async throws {
        
    }
    
    func sendEndCall(to destinationID: PeerID) async throws {
        
    }
    
    func onConnectionSatisfied() {
        
    }
    
    func onConnectionUnsatisfied() {
        
    }
    
    func clearMessageQueue() {
        
    }
}
