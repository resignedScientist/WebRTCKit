import Foundation

/// This actor manages a cache for ICE (Interactive Connectivity Establishment) candidates.
///
/// ICE candidates are pieces of data used in WebRTC (Web Real-Time Communication)
/// to establish peer-to-peer connections.
/// This actor provides methods to store, retrieve, and clear these candidates
/// in a thread-safe manner using the actor model.
actor ICECandidateCache {
    
    /// An array that holds cached ICE candidates.
    private var cachedICECandidates: [Data] = []
    
    /// Stores a new ICE candidate.
    /// - Parameter candidate: The ICE candidate data to be cached.
    func store(_ candidate: Data) {
        cachedICECandidates.append(candidate)
    }
    
    /// Retrieves the most recently cached ICE candidate and removes it from the cache.
    /// - Returns: The most recent ICE candidate data, or `nil` if the cache is empty.
    func getNext() -> Data? {
        cachedICECandidates.popLast()
    }
    
    /// Clears all cached ICE candidates.
    func clear() {
        cachedICECandidates.removeAll()
    }
}
