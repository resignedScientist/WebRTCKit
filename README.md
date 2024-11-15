WebRTCKit is a repository that simplifies WebRTC for the use in an iOS app. It is specialized for simple peer-to-peer video calls between two peers. 

# Features
- Create calls between two peers that support video & audio.
- Add data channels.
- Use your own signaling server using our delegate.
- Automatic Bitrate adjustment based on network conditions.

# WARNING

This repository is still in alpha state. That means, that is it not 100% stable or tested and everything you see is subject to change.

# Installation

You can use Swift Package Manager to integrate WebRTCKit into your app using this URL:

```
https://github.com/resignedScientist/WebRTCKit.git
```

# Usage

First, you need to set the delegate and setup the connection.
```swift
// Set the delegate.
await webRTCController.setCallManagerDelegate(self)

// Setup the connection, connecting and registering to the signaling server.
let localPeerID = try await webRTCController.setupConnection()
```

Start the recording of audio & video like this:

```swift
try await webRTCController.startRecording
```

To start a call, you can call the controller providing the ID of your peer:

```swift
try await webRTCController.sendCallRequest(to: peerID)
```

The other peer can answer the call:
```swift
try await webRTCController.answerCallRequest(accept: true)
```

…or reject it:
```swift
try await webRTCController.answerCallRequest(accept: false)
```

Finally, this is how you end the call:
```swift
try await webRTCController.endCall()
```

# Setup

You can setup WebRTCKit like this. Run this when your application starts and keep a reference to the `WebRTCController`.

There are two mendatory parameters `signalingServer` and `config` that I will explain below.

```swift
let signalingServer = await SignalingServerConnectionImpl()
let webRTCController = await WebRTCKit.initialize(
    signalingServer: signalingServer,
    config: config
)
```

## Config

I recommend to put the config into a JSON file like this:

```JSON
{
    "iceServers": [
        {
            "urlStrings": [
                "stun:example.com:1234"
            ]
        },
        {
            "urlStrings": [
                "turn:example.com:1234"
            ],
            "username": "username",
            "credential": "credential"
        }
    ],
    "connectionTimeout": 30,
    "video": {
        "minBitrate": 100000,
        "maxBitrate": 6000000,
        "startBitrate": 1000000,
        "bitrateStepUp": 0.15,
        "bitrateStepDown": 0.15,
        "bitrateStepCriticalDown": 0.50,
        "criticalPacketLossThreshold": 0.10,
        "highPacketLossThreshold": 0.05,
        "lowPacketLossThreshold": 0.01
    },
    "audio": {
        "minBitrate": 6000,
        "maxBitrate": 96000,
        "startBitrate": 16000,
        "bitrateStepUp": 0.15,
        "bitrateStepDown": 0.15,
        "bitrateStepCriticalDown": 0.50,
        "criticalPacketLossThreshold": 0.10,
        "highPacketLossThreshold": 0.05,
        "lowPacketLossThreshold": 0.01
    }
}
```

### Config Parameters

Here a short explanation of each parameter:

```swift
/// The ICE-Servers to use for connection establishment.
public let iceServers: [RTCIceServer]

/// The number of seconds we can be in the connecting state before aborting the call.
public let connectionTimeout: UInt64

/// The bitrate configuration for video data.
public let video: BitrateConfig

/// The bitrate configuration for audio data.
public let audio: BitrateConfig
```

#### BitrateConfig

There is an automatic Bitrate adjustment integrated that you can configure here.

```swift
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
```

There are some default values for audio & video bitrates as well that worked for me:

```swift
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
```

## Signaling Server

Just like in WebRTC itself, you have to provide your own signaling server that helps to establish a peer-to-peer connection between two devices.

For this reason the `SignalingServerConnection` protocol exists. You need to implement this and send messages through your server to the other peer.

I recommend using [`Starscream`](https://github.com/daltoniam/Starscream) to connect to your WebSocket server.

```swift
public protocol SignalingServerConnection: Sendable {
    
    /// Returns true if the connection is established / open.
    var isOpen: Bool { get }
    
    /// Set the delegate.
    func setDelegate(_ delegate: SignalingServerDelegate?)
    
    /// Establish a connection to the signaling server and receive the peer id.
    func connect() async throws -> PeerID
    
    /// Disconnect from the signaling server.
    func disconnect()
    
    /// Send a signal to the other peer through the signaling server.
    /// - Parameters:
    ///   - signal: The signal to send as data.
    ///   - destinationID: The ID of the other peer.
    func sendSignal(_ signal: Data, to destinationID: PeerID) async throws
    
    /// Send an ICE candidate to the other peer through the signaling server.
    /// - Parameters:
    ///   - candidate: The ICE candidate as data.
    ///   - destinationID: The ID of the other peer.
    func sendICECandidate(_ candidate: Data, to destinationID: PeerID) async throws
    
    /// Notify the other peer that we end the call.
    /// - Parameter destinationID: The ID of the other peer.
    func sendEndCall(to destinationID: PeerID) async throws
    
    /// The network connection has been re-established.
    func onConnectionSatisfied()
    
    /// The network connection was lost.
    func onConnectionUnsatisfied()
}
```