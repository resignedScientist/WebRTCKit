//
//  Call.swift
//  CallKitDemoApp
//
//  Created by Norman Laudien on 26.03.2026.
//

import Foundation

struct Call {
    let uuid: UUID
    let handle: String
    let direction: CallDirection
    let isMuted: Bool
    
    func muted(_ isMuted: Bool) -> Call {
        Call(
            uuid: uuid,
            handle: handle,
            direction: direction,
            isMuted: isMuted
        )
    }
}
