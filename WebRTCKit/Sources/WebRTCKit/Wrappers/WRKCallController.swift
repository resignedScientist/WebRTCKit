import CallKit

@WebRTCActor
protocol WRKCallController: AnyObject, Sendable {
    
    func request(_ transaction: CXTransaction) async throws
}

final class WRKCallControllerImpl: WRKCallController, Sendable {
    
    private let controller: CXCallController
    
    init(_ controller: CXCallController) {
        self.controller = controller
    }
    
    func request(_ transaction: CXTransaction) async throws {
        #if !targetEnvironment(simulator)
        return try await withCheckedThrowingContinuation { continuation in
            controller.altRequest(transaction) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        #endif
    }
}

/// Extension to prevent a crash caused by the compiler assuming the callback
/// is being run on the same actor / queue as the call itself.
private extension CXCallController {
    
    func altRequest(_ transaction: CXTransaction, completion: @escaping @Sendable (Error?) -> Void) {
        request(transaction) { error in
            WebRTCActor.checkAsync {
                completion(error)
            }
        }
    }
}

@WebRTCActor
protocol CallAction: Sendable {
    
}

struct StartCallAction: CallAction {
    let callUUID: UUID
    let handle: CallHandle
    let fulfill: () -> Void
    let fail: () -> Void
    
    init(from action: CXStartCallAction) {
        self.callUUID = action.callUUID
        self.handle = CallHandle(from: action.handle)
        self.fulfill = action.fulfill
        self.fail = action.fail
    }
}

struct AnswerCallAction: CallAction {
    let callUUID: UUID
    let fulfill: () -> Void
    let fail: () -> Void
    
    init(from action: CXAnswerCallAction) {
        self.callUUID = action.callUUID
        self.fulfill = action.fulfill
        self.fail = action.fail
    }
}

struct EndCallAction: CallAction {
    let callUUID: UUID
    let fulfill: () -> Void
    let fail: () -> Void
    
    init(from action: CXEndCallAction) {
        self.callUUID = action.callUUID
        self.fulfill = action.fulfill
        self.fail = action.fail
    }
}
