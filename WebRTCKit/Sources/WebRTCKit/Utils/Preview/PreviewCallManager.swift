import Foundation

final class PreviewCallManager: CallManager {
    
    private weak var delegate: CallManagerDelegate?
    
    func getState() async -> CallManagerState {
        .idle
    }
    
    func setDelegate(_ delegate: CallManagerDelegate?) {
        self.delegate = delegate
    }
    
    func setup() {
        
    }
    
    func sendCallRequest(to peerID: PeerID) async throws {
        
    }
    
    func answerCallRequest(accept: Bool) async throws {
        
    }
    
    func didAcceptCallRequest() async {
        
    }
    
    func endCall() async throws {
        
    }
    
    func disconnect() async throws {
        
    }
    
    func shouldActivateAudioSession() {
        
    }
    
    func shouldDeactivateAudioSession() {
        
    }
}
