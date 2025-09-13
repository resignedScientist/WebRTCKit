import Foundation

final class PreviewCallManager: CallManager {
    
    private weak var delegate: CallManagerDelegate?
    
    func getState() async -> CallManagerState {
        .idle
    }
    
    func setDelegate(_ delegate: CallManagerDelegate?) {
        self.delegate = delegate
    }
    
    func setAutoAcceptCalls(autoAccept: Bool) async {
        
    }
    
    func setup() {
        
    }
    
    func reportIncomingVoIPCall() async throws {
        
    }
    
    func sendCallRequest(to peerID: PeerID) async throws {
        
    }
    
    func answerCallRequest(accept: Bool) async throws {
        
    }
    
    func onStartCallAction(to remotePeerID: PeerID) async throws {
        
    }
    
    func onAnswerCallAction() async throws {
        
    }
    
    func onEndCallAction() async throws {
        
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
