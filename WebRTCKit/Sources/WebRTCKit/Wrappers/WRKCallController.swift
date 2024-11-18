import CallKit

protocol WRKCallController: AnyObject, Sendable {
    
    func request(_ transaction: CXTransaction) async throws
}

final class WRKCallControllerImpl: WRKCallController, @unchecked Sendable {
    
    private let controller: CXCallController
    private let queue = DispatchQueue(label: "com.webrtckit.WRKCallController")
    
    init(_ controller: CXCallController) {
        self.controller = controller
    }
    
    func request(_ transaction: CXTransaction) async throws {
        #if !targetEnvironment(simulator)
        let transaction = CallTransaction(from: transaction)
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.controller.request(transaction.toCXTransaction()) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        #endif
    }
}

protocol CallAction: Sendable {
    
    func toCXAction() -> CXAction
}

struct StartCallAction: CallAction {
    let callUUID: UUID
    let handle: CallHandle
    
    init(from action: CXStartCallAction) {
        self.callUUID = action.callUUID
        self.handle = CallHandle(from: action.handle)
    }
    
    func toCXAction() -> CXAction {
        CXStartCallAction(
            call: callUUID,
            handle: handle.toCXHandle()
        )
    }
}

struct AnswerCallAction: CallAction {
    let callUUID: UUID
    
    init(from action: CXAnswerCallAction) {
        self.callUUID = action.callUUID
    }
    
    func toCXAction() -> CXAction {
        CXAnswerCallAction(call: callUUID)
    }
}

struct EndCallAction: CallAction {
    let callUUID: UUID
    
    init(from action: CXEndCallAction) {
        self.callUUID = action.callUUID
    }
    
    func toCXAction() -> CXAction {
        CXEndCallAction(call: callUUID)
    }
}

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
    
    func toCXTransaction() -> CXTransaction {
        CXTransaction(actions: actions.map {
            $0.toCXAction()
        })
    }
}
