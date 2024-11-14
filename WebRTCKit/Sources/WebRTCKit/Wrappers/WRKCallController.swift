import CallKit

protocol WRKCallController: AnyObject, Sendable {
    
    func request(_ transaction: CXTransaction) async throws
}

final class WRKCallControllerImpl: WRKCallController {
    
    let controller: CXCallController
    
    init(_ controller: CXCallController) {
        self.controller = controller
    }
    
    func request(_ transaction: CXTransaction) async throws {
        #if !targetEnvironment(simulator)
        try await controller.request(transaction)
        #endif
    }
}
