struct UnsafeSendable<T>: @unchecked Sendable {
    var wrappedValue: T
}
