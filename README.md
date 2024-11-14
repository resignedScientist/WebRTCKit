# WebRTCKit

WebRTCKit is a repository that simplifies WebRTC for the use in an iOS app. It is specialized for simple peer-to-peer video calls between two peers. 

### Features
- Create calls between two peers that support video & audio.
- Add data channels.
- Use your own signaling server using our delegate.

## WARNING

This repository is still in alpha state. That means, that is it not 100% stable or tested and everything you see is subject to change.

## Installation

You can use Swift Package Manager to integrate WebRTCKit into your app using this URL:

```
https://github.com/resignedScientist/WebRTCKit.git
```

## Setup

You can setup WebRTCKit like this. Run this when your application starts and keep a reference to the `WebRTCController`.

```swift
let signalingServer = await SignalingServerConnectionImpl()
let webRTCController = await WebRTCKit.initialize(
    signalingServer: signalingServer,
    config: config
)
```
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