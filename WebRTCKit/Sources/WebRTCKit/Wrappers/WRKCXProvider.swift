import AVKit
import CallKit

@WebRTCActor
final class WRKCXProvider: NSObject, Sendable {
    private let provider: CXProvider
    private weak var delegate: CallProviderDelegate?
    
    init(configuration: CXProviderConfiguration) {
        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: WebRTCActor.queue)
    }
    
    /// Set delegate and optional queue for delegate callbacks to be performed on.
    /// A nil queue implies that delegate callbacks should happen on the main queue. The delegate is stored weakly
    func setDelegate(_ delegate: CallProviderDelegate?) {
        self.delegate = delegate
    }
    
    /// Report a new incoming call to the system.
    ///
    /// If completion is invoked with a non-nil `error`, the incoming call has been disallowed by the system and will not be displayed, so the provider should not proceed with the call.
    ///
    /// Completion block will be called on delegate queue, if specified, otherwise on a private serial queue.
    func reportNewIncomingCall(with UUID: UUID, update: CXCallUpdate) async throws {
//        let update = CallUpdate(from: update)
        return try await withCheckedThrowingContinuation { continuation in
            provider.reportNewIncomingCall(
                with: UUID,
                update: update//.toCXCallUpdate()
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - CXProviderDelegate

// @preconcurrency is safe here as we set the WebRTCActors queue to the provider,
// so it uses this queue to call delegate methods.
extension WRKCXProvider: @preconcurrency CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        Task { @WebRTCActor in
            await delegate?.providerDidReset(self)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task { @WebRTCActor in
            await delegate?.provider(self, perform: action)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @WebRTCActor in
            await delegate?.provider(self, perform: action)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @WebRTCActor in
            await delegate?.provider(self, perform: action)
        }
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Task { @WebRTCActor in
            await delegate?.provider(self, didActivate: audioSession)
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Task { @WebRTCActor in
            await delegate?.provider(self, didDeactivate: audioSession)
        }
    }
}

// MARK: -

struct CallUpdate: Sendable {
    
    let remoteHandle: CallHandle?
    let localizedCallerName: String?
    let supportsHolding: Bool
    let supportsGrouping: Bool
    let supportsUngrouping: Bool
    let supportsDTMF: Bool
    let hasVideo: Bool
    
    init(from update: CXCallUpdate) {
        self.remoteHandle = CallHandle(from: update.remoteHandle)
        self.localizedCallerName = update.localizedCallerName
        self.supportsHolding = update.supportsHolding
        self.supportsGrouping = update.supportsGrouping
        self.supportsUngrouping = update.supportsUngrouping
        self.supportsDTMF = update.supportsDTMF
        self.hasVideo = update.hasVideo
    }
    
    func toCXCallUpdate() -> CXCallUpdate {
        let update = CXCallUpdate()
        update.remoteHandle = remoteHandle?.toCXHandle()
        update.localizedCallerName = localizedCallerName
        update.supportsHolding = supportsHolding
        update.supportsGrouping = supportsGrouping
        update.supportsUngrouping = supportsUngrouping
        update.supportsDTMF = supportsDTMF
        update.hasVideo = hasVideo
        return update
    }
}

struct CallHandle: Sendable {
    let type: CXHandle.HandleType
    let value: String
    
    init?(from handle: CXHandle?) {
        guard let handle else { return nil }
        self.type = handle.type
        self.value = handle.value
    }
    
    init(from handle: CXHandle) {
        self.type = handle.type
        self.value = handle.value
    }
    
    func toCXHandle() -> CXHandle {
        CXHandle(
            type: type,
            value: value
        )
    }
}

// MARK: -

protocol CallProviderDelegate: AnyObject, Sendable {
    
    func providerDidReset(_ provider: WRKCXProvider) async
    
    func provider(_ provider: WRKCXProvider, perform action: CXStartCallAction) async
    
    func provider(_ provider: WRKCXProvider, perform action: CXAnswerCallAction) async
    
    func provider(_ provider: WRKCXProvider, perform action: CXEndCallAction) async
    
    func provider(_ provider: WRKCXProvider, didActivate audioSession: AVAudioSession) async
    
    func provider(_ provider: WRKCXProvider, didDeactivate audioSession: AVAudioSession) async
}
