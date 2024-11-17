import WebRTC

public protocol WRKMediaStream: AnyObject, Sendable {
    
    var audioTracks: [WRKRTCAudioTrack] { get }
    
    var videoTracks: [WRKRTCVideoTrack] { get }
    
    func addAudioTrack(_ audioTrack: WRKRTCAudioTrack)
    
    func addVideoTrack(_ videoTrack: WRKRTCVideoTrack) async
}

final class WRKMediaStreamImpl: WRKMediaStream, @unchecked Sendable {
    
    let mediaStream: RTCMediaStream
    private let queue = DispatchQueue(label: "com.webrtckit.WRKMediaStream")
    
    var audioTracks: [WRKRTCAudioTrack] {
        queue.sync {
            mediaStream.audioTracks.map {
                WRKRTCAudioTrackImpl($0)
            }
        }
    }
    
    var videoTracks: [WRKRTCVideoTrack] {
        queue.sync {
            mediaStream.videoTracks.map {
                WRKRTCVideoTrackImpl($0)
            }
        }
    }
    
    init(_ mediaStream: RTCMediaStream) {
        self.mediaStream = mediaStream
    }
    
    func addAudioTrack(_ audioTrack: WRKRTCAudioTrack) {
        queue.sync {
            if let audioTrack = (audioTrack as? WRKRTCAudioTrackImpl)?.audioTrack {
                mediaStream.addAudioTrack(audioTrack)
            }
        }
    }
    
    func addVideoTrack(_ videoTrack: WRKRTCVideoTrack) {
        queue.sync {
            if let videoTrack = (videoTrack as? WRKRTCVideoTrackImpl)?.videoTrack {
                mediaStream.addVideoTrack(videoTrack)
            }
        }
    }
}
