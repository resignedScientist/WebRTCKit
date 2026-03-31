import Foundation

final class DummyCallEstablisher: CallEstablisher {
    
    private var delegate: CallEstablisherDelegate?
    
    func setDelegate(_ delegate: CallEstablisherDelegate?) {
        self.delegate = delegate
    }
    
    func answerCall(_ callUUID: UUID) {
        Task {
            delegate?.callDidStartConnecting(callUUID)
            
            // answer call here…
            do {
                try await Task.sleep(for: .seconds(3))
                
                // at some point it gets connected
                delegate?.callDidConnect(callUUID)
            } catch {
                print("answerCall failed - \(error)")
                delegate?.callDidEnd(callUUID, reason: .failed)
            }
        }
    }
    
    func startCall(_ callUUID: UUID, handle: String) {
        Task {
            
            do {
                // starting call here…
                try await Task.sleep(for: .seconds(3))
                
                // at some point it will start connecting…
                
                delegate?.callDidStartConnecting(callUUID)
                
                try await Task.sleep(for: .seconds(3))
                
                // at some point it gets connected
                delegate?.callDidConnect(callUUID)
                
            } catch {
                print("startCall failed - \(error)")
                delegate?.callDidEnd(callUUID, reason: .failed)
            }
        }
    }
    
    func endCall(_ callUUID: UUID) {
        Task {
            do {
                // ending call here
                try await Task.sleep(for: .seconds(3))
                
                // at some point the call was ended properly
                delegate?.callDidEnd(callUUID, reason: .remoteEnded)
                
            } catch {
                print("endCall failed - \(error)")
                delegate?.callDidEnd(callUUID, reason: .failed)
            }
        }
    }
    
    func setCallMuted(_ isMuted: Bool) {
        // mute the call here…
    }
}
