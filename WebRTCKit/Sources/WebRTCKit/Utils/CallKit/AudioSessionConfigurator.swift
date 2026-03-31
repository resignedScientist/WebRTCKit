//
//  CallAudioSessionConfigurator.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

@MainActor
protocol AudioSessionConfigurator: Sendable {
    
    func configureAudioSession()
    
    func startAudio()
    
    func stopAudio()
}

struct AudioSessionConfiguratorImpl: AudioSessionConfigurator {
    
    func configureAudioSession() {
        // TODO: use EyeScanFoundation classes to configure audio session
    }
    
    func startAudio() {
        // TODO: use EyeScanFoundation classes to start audio processing
    }
    
    func stopAudio() {
        // TODO: use EyeScanFoundation classes to stop audio processing
    }
}
