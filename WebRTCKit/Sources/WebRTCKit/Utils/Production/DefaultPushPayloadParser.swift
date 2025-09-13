import Foundation

struct DefaultPushPayloadParser: PushPayloadParser {
    
    func parse(_ payload: PushPayload) throws -> ParsedPushPayload {
        let decoder = JSONDecoder()
        return try decoder.decode(ParsedPushPayload.self, from: payload.data)
    }
}
