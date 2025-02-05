@propertyWrapper struct Inject<T> {
    
    private let keyPath: KeyPath<DIContainer, T>
    private var container: DIContainer {
        DIContainer.Instance.shared!
    }
    
    init(_ keyPath: KeyPath<DIContainer, T>) {
        self.keyPath = keyPath
    }
    
    var wrappedValue: T {
        container[keyPath: keyPath]
    }
}
