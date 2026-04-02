//
//  CallAudioSessionConfigurator.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

@MainActor
public protocol AudioSessionConfigurator {
    
    func configureAudioSession(completion: @escaping (_ success: Bool) -> Void)
    
    func startAudio()
    
    func stopAudio()
}

struct MockAudioSessionConfigurator: AudioSessionConfigurator {
    
    func configureAudioSession(completion: @escaping (_ success: Bool) -> Void) {
        completion(true)
    }
    
    func startAudio() {
        
    }
    
    func stopAudio() {
        
    }
}
