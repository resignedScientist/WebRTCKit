import Foundation

@globalActor public actor WebRTCActor {
    public static let shared = WebRTCActor()
    
    public static let queue = DispatchSerialQueue(label: "com.webrtckit.actor")
    
    nonisolated public var unownedExecutor: UnownedSerialExecutor { WebRTCActor.queue.asUnownedSerialExecutor() }
}
