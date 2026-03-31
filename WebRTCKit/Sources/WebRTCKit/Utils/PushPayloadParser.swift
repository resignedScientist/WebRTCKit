public protocol PushPayloadParser {
    func parse(_ payload: PushPayload) throws -> ParsedPushPayload
}
