import Foundation

private let queueKey = DispatchSpecificKey<String>()
private let queueLabel = "com.webrtckit.actor"

/// The main actor of the framework to ensure data race safety.
@globalActor public actor WebRTCActor {
    public static let shared = WebRTCActor()
    
    /// The queue that acts as the executor of the actor.
    /// So everything running in the queue belongs to this actor and vice versa.
    public static let queue = {
        let queue = DispatchSerialQueue(label: queueLabel)
        queue.setSpecific(key: queueKey, value: queueLabel)
        return queue
    }()
    
    nonisolated public var unownedExecutor: UnownedSerialExecutor { WebRTCActor.queue.asUnownedSerialExecutor() }
    
    public nonisolated static func isRunningOnQueue() -> Bool {
        DispatchQueue.getSpecific(key: queueKey) == queueLabel
    }
    
    /// Sync that prevents dead lock by checking the queue first.
    public static func checkSync<T>(execute work: () throws -> T) rethrows -> T {
        if isRunningOnQueue() {
            return try work()
        } else {
            return try queue.sync(execute: work)
        }
    }
    
    /// Sync that prevents dead lock by checking the queue first.
    public static func checkSync(execute work: DispatchWorkItem) {
        if isRunningOnQueue() {
            work.perform()
        } else {
            queue.sync(execute: work)
        }
    }
    
    public static func checkAsync(execute work: @escaping @Sendable () -> Void) {
        if isRunningOnQueue() {
            work()
        } else {
            queue.async(execute: work)
        }
    }
}
