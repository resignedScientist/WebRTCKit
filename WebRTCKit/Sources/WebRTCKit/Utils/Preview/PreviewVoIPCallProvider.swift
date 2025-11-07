import Foundation

final class PreviewVoIPCallProvider: VoIPCallProvider {
    
    func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool) async throws {
        
    }
    
    func startOutgoingCall(uuid: UUID, handle: String, hasVideo: Bool) async throws {
        
    }
    
    func acceptIncomingCall() async throws {
        
    }
    
    func endCall() async throws {
        
    }
    
    func setCurrentCallID(_ id: UUID) throws {
        
    }
    
    func getCurrentCallID() -> UUID? {
        nil
    }
    
    func isCallRunning() -> Bool {
        false
    }
    
    func answeredElsewhere() throws {
        
    }
}
