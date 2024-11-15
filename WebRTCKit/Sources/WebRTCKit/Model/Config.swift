import WebRTC

typealias Config = WebRTCKit.Config



public extension WebRTCKit {
    
    struct Config: Sendable {
        
        /// The ICE-Servers to use for connection establishment.
        public let iceServers: [RTCIceServer]
        
        /// The number of seconds we can be in the connecting state before aborting the call.
        public let connectionTimeout: UInt64
        
        /// The bitrate configuration for video data.
        public let video: BitrateConfig
        
        /// The bitrate configuration for audio data.
        public let audio: BitrateConfig
        
        static var preview: Config {
            Config(
                iceServers: [],
                connectionTimeout: 2,
                video: .defaultForVideo,
                audio: .defaultForAudio
            )
        }
        
        public init(
            iceServers: [RTCIceServer],
            connectionTimeout: UInt64,
            video: BitrateConfig,
            audio: BitrateConfig
        ) {
            self.iceServers = iceServers
            self.connectionTimeout = connectionTimeout
            self.video = video
            self.audio = audio
        }
    }
}

extension Config: Codable {
    
    enum CodingKeys: CodingKey {
        case iceServers
        case connectionTimeout
        case video
        case audio
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let iceServers = try container.decodeIfPresent([ICEServer].self, forKey: .iceServers) ?? []
        
        self.iceServers = iceServers.map {
            RTCIceServer(
                urlStrings: $0.urlStrings,
                username: $0.username,
                credential: $0.credential,
                tlsCertPolicy: $0.tlsCertPolicy,
                hostname: $0.hostname,
                tlsAlpnProtocols: $0.tlsAlpnProtocols,
                tlsEllipticCurves: $0.tlsEllipticCurves
            )
        }
        self.connectionTimeout = try container.decode(UInt64.self, forKey: .connectionTimeout)
        self.video = try container.decode(BitrateConfig.self, forKey: .video)
        self.audio = try container.decode(BitrateConfig.self, forKey: .audio)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let iceServers = iceServers.map {
            ICEServer(
                urlStrings: $0.urlStrings,
                username: $0.username,
                credential: $0.credential,
                tlsCertPolicy: $0.tlsCertPolicy,
                hostname: $0.hostname,
                tlsAlpnProtocols: $0.tlsAlpnProtocols,
                tlsEllipticCurves: $0.tlsEllipticCurves
            )
        }
        
        try container.encode(iceServers, forKey: .iceServers)
        try container.encode(video, forKey: .video)
    }
}

private struct ICEServer: Codable {
    let urlStrings: [String]
    let username: String?
    let credential: String?
    let tlsCertPolicy: RTCTlsCertPolicy
    let hostname: String?
    let tlsAlpnProtocols: [String]?
    let tlsEllipticCurves: [String]?
}

extension ICEServer {
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.urlStrings = try container.decode([String].self, forKey: .urlStrings)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.credential = try container.decodeIfPresent(String.self, forKey: .credential)
        self.tlsCertPolicy = try container.decodeIfPresent(RTCTlsCertPolicy.self, forKey: .tlsCertPolicy) ?? .secure
        self.hostname = try container.decodeIfPresent(String.self, forKey: .hostname)
        self.tlsAlpnProtocols = try container.decodeIfPresent([String].self, forKey: .tlsAlpnProtocols)
        self.tlsEllipticCurves = try container.decodeIfPresent([String].self, forKey: .tlsEllipticCurves)
    }
}

extension RTCTlsCertPolicy: Codable {
    
}

public extension Config {
    
    struct BitrateConfig: Codable, Sendable {
        
        /// The bitrate does not go below this value.
        let minBitrate: Int
        
        /// The bitrate does not go above this value.
        let maxBitrate: Int
        
        /// The initial bitrate to try when the call starts.
        let startBitrate: Int
        
        /// If network conditions are good, step up this percentage (value between 0-1).
        let bitrateStepUp: Double
        
        /// If network conditions are bad, step down this percentage (value between 0-1).
        let bitrateStepDown: Double
        
        /// If network conditions are critical, step down this percentage (value between 0-1).
        let bitrateStepCriticalDown: Double
        
        /// The percentage threshold when packet loss counts as critical (value between 0-1).
        let criticalPacketLossThreshold: Double
        
        /// The percentage threshold when packet loss counts as high (value between 0-1).
        let highPacketLossThreshold: Double
        
        /// The percentage threshold under which packet loss counts as low (value between 0-1).
        let lowPacketLossThreshold: Double
        
        public static var defaultForVideo: BitrateConfig {
            BitrateConfig(
                minBitrate: 100_000,
                maxBitrate: 6_000_000,
                startBitrate: 1_000_000,
                bitrateStepUp: 0.15,
                bitrateStepDown: 0.15,
                bitrateStepCriticalDown: 0.25,
                criticalPacketLossThreshold: 0.10,
                highPacketLossThreshold: 0.05,
                lowPacketLossThreshold: 0.01
            )
        }
        
        public static var defaultForAudio: BitrateConfig {
            BitrateConfig(
                minBitrate: 6_000,
                maxBitrate: 96_000,
                startBitrate: 16_000,
                bitrateStepUp: 0.15,
                bitrateStepDown: 0.15,
                bitrateStepCriticalDown: 0.25,
                criticalPacketLossThreshold: 0.10,
                highPacketLossThreshold: 0.05,
                lowPacketLossThreshold: 0.01
            )
        }
    }
}
