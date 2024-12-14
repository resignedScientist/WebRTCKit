import Foundation

/// The main actor of the framework to ensure data race safety.
@globalActor public actor WebRTCActor {
    public static let shared = WebRTCActor()
    
    /// The queue that acts as the executor of the actor.
    /// So everything running in the queue belongs to this actor and vice versa.
    public static let queue = DispatchSerialQueue(label: "com.webrtckit.actor")
    
    nonisolated public var unownedExecutor: UnownedSerialExecutor { WebRTCActor.queue.asUnownedSerialExecutor() }
}
