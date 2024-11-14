import Foundation

extension Array where Element == Task<Void, Never> {
    
    mutating func cancelAll() {
        forEach { $0.cancel() }
        removeAll()
    }
}

extension Task where Success == Void, Failure == Never {
    
    func store(in array: inout [Self]) {
        array.append(self)
    }
}
