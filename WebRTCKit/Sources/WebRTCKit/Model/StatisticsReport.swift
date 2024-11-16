import WebRTC

struct StatisticsReport: Sendable {
    let statistics: [String: Statistics]
    
    init(statistics: [String: RTCStatistics]) {
        self.statistics = statistics.reduce(into: [:]) {
            $0[$1.key] = Statistics(stats: $1.value)
        }
    }
}

struct Statistics {
    let kind: BitrateType
    let type: StatisticsType
    let packetsLost: Int?
    let packetsSent: Int?
    
    init?(stats: RTCStatistics) {
        guard
            let kindStr = stats.values["kind"] as? NSString,
            let kind = BitrateType(rawValue: kindStr as String),
            let type = StatisticsType(rawValue: stats.type)
        else { return nil }
        
        self.kind = kind
        self.type = type
        self.packetsLost = (stats.values["packetsLost"] as? NSNumber)?.intValue
        self.packetsSent = (stats.values["packetsSent"] as? NSNumber)?.intValue
    }
}

enum StatisticsType: String {
    case remoteInboundRtp = "remote-inbound-rtp"
    case outboundRtp = "outbound-rtp"
}
