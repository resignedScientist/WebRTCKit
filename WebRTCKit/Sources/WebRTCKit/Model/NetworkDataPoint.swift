import Foundation

struct NetworkDataPoint: Sendable, Equatable {
    
    /// The total packets sent since call start.
    let packetsSent: Int
    
    /// The total packets lost since call start.
    let packetsLost: Int
    
    /// The timestamp of this data snippet.
    let timestamp: Date
}
