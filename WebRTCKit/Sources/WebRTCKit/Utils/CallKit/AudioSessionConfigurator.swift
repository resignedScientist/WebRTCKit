//
//  CallAudioSessionConfigurator.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

public protocol AudioSessionConfigurator: Sendable {
    
    func configureAudioSession()
    
    func startAudio()
    
    func stopAudio()
}

struct MockAudioSessionConfigurator: AudioSessionConfigurator {
    
    func configureAudioSession() {
        
    }
    
    func startAudio() {
        
    }
    
    func stopAudio() {
        
    }
}
