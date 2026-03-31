public protocol PushPayloadParser: Sendable {
    func parse(_ payload: PushPayload) throws -> ParsedPushPayload
}
