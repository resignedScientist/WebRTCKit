import Foundation

actor ICECandidateCache {
    
    private var cachedICECandidates: [Data] = []
    
    func store(_ candidate: Data) {
        cachedICECandidates.append(candidate)
    }
    
    func getNext() -> Data? {
        cachedICECandidates.popLast()
    }
    
    func clear() {
        cachedICECandidates.removeAll()
    }
}
