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
            WebRTCActor.queue.async {
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

@WebRTCActor
struct CallTransaction: Sendable {
    
    let actions: [CallAction]
    
    init(from transaction: CXTransaction) {
        actions = transaction.actions.compactMap {
            if let startCallAction = $0 as? CXStartCallAction {
                return StartCallAction(from: startCallAction)
            }
            if let answerCallAction = $0 as? CXAnswerCallAction {
                return AnswerCallAction(from: answerCallAction)
            }
            if let endCallAction = $0 as? CXEndCallAction {
                return EndCallAction(from: endCallAction)
            }
            return nil
        }
    }
    
    /// WARNING: this does not keep the fulfill & fail actions! Use with caution!
    func toCXTransaction() -> CXTransaction {
        CXTransaction(
            actions: actions.compactMap {
                if let startCallAction = $0 as? StartCallAction {
                    return CXStartCallAction(
                        call: startCallAction.callUUID,
                        handle: startCallAction.handle.toCXHandle()
                    )
                }
                if let answerCallAction = $0 as? AnswerCallAction {
                    return CXAnswerCallAction(call: answerCallAction.callUUID)
                }
                if let endCallAction = $0 as? EndCallAction {
                    return CXEndCallAction(call: endCallAction.callUUID)
                }
                return nil
            }
        )
    }
}
