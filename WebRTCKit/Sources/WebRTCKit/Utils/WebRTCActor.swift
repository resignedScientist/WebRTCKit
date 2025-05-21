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
}
