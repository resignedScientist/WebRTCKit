import WebRTC

public typealias WebRTCKitConfig = WebRTCKit.Config
public typealias BitrateConfig = WebRTCKit.Config.Bitrate

public extension WebRTCKit {
    
    struct Config: Sendable, Codable {
        
        /// The ICE-Servers to use for connection establishment.
        public let iceServers: [ICEServer]
        
        /// The number of seconds we can be in the connecting state before aborting the call.
        public let connectionTimeout: UInt64
        
        /// The bitrate configuration for video data.
        public let video: BitrateConfig
        
        /// The bitrate configuration for audio data.
        public let audio: BitrateConfig
        
        public static var preview: Config {
            Config(
                iceServers: [],
                connectionTimeout: 2,
                video: .defaultForVideo,
                audio: .defaultForAudio
            )
        }
        
        /// - Parameters:
        ///   - iceServers: The ICE-Servers to use for connection establishment.
        ///   - connectionTimeout: The number of seconds we can be in the connecting state before aborting the call.
        ///   - video: The bitrate configuration for video data.
        ///   - audio: The bitrate configuration for audio data.
        public init(
            iceServers: [ICEServer]? = nil,
            connectionTimeout: UInt64? = nil,
            video: BitrateConfig? = nil,
            audio: BitrateConfig? = nil
        ) {
            self.iceServers = iceServers ?? []
            self.connectionTimeout = connectionTimeout ?? 30
            self.video = video ?? .defaultForVideo
            self.audio = audio ?? .defaultForAudio
        }
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<WebRTCKit.Config.CodingKeys> = try decoder.container(keyedBy: WebRTCKit.Config.CodingKeys.self)
            let iceServers = try container.decode([ICEServer].self, forKey: WebRTCKit.Config.CodingKeys.iceServers)
            let connectionTimeout = try container.decode(UInt64.self, forKey: WebRTCKit.Config.CodingKeys.connectionTimeout)
            let video = try container.decode(BitrateConfig.self, forKey: WebRTCKit.Config.CodingKeys.video)
            let audio = try container.decode(BitrateConfig.self, forKey: WebRTCKit.Config.CodingKeys.audio)
            
            self.init(
                iceServers: iceServers,
                connectionTimeout: connectionTimeout,
                video: video,
                audio: audio
            )
        }
    }
}

public struct ICEServer: Codable, Sendable {
    let urlStrings: [String]
    let username: String?
    let credential: String?
    let tlsCertPolicy: RTCTlsCertPolicy
    let hostname: String?
    let tlsAlpnProtocols: [String]?
    let tlsEllipticCurves: [String]?
    
    public init(
        urlStrings: [String],
        username: String? = nil,
        credential: String? = nil,
        tlsCertPolicy: RTCTlsCertPolicy? = nil,
        hostname: String? = nil,
        tlsAlpnProtocols: [String]? = nil,
        tlsEllipticCurves: [String]? = nil
    ) {
        self.urlStrings = urlStrings
        self.username = username
        self.credential = credential
        self.tlsCertPolicy = tlsCertPolicy ?? .secure
        self.hostname = hostname
        self.tlsAlpnProtocols = tlsAlpnProtocols
        self.tlsEllipticCurves = tlsEllipticCurves
    }
}

extension ICEServer {
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let urlStrings = try container.decode([String].self, forKey: .urlStrings)
        let username = try container.decodeIfPresent(String.self, forKey: .username)
        let credential = try container.decodeIfPresent(String.self, forKey: .credential)
        let tlsCertPolicy = try container.decodeIfPresent(RTCTlsCertPolicy.self, forKey: .tlsCertPolicy)
        let hostname = try container.decodeIfPresent(String.self, forKey: .hostname)
        let tlsAlpnProtocols = try container.decodeIfPresent([String].self, forKey: .tlsAlpnProtocols)
        let tlsEllipticCurves = try container.decodeIfPresent([String].self, forKey: .tlsEllipticCurves)
        
        self.init(
            urlStrings: urlStrings,
            username: username,
            credential: credential,
            tlsCertPolicy: tlsCertPolicy,
            hostname: hostname,
            tlsAlpnProtocols: tlsAlpnProtocols,
            tlsEllipticCurves: tlsEllipticCurves
        )
    }
}

extension RTCTlsCertPolicy: Codable {}

public extension WebRTCKit.Config {
    
    struct Bitrate: Codable, Sendable {
        
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
        
        public static var defaultForVideo: Bitrate {
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
        
        public static var defaultForAudio: Bitrate {
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
