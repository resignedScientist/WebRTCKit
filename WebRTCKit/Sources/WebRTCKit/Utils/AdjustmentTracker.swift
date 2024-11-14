import Foundation

/// Track bitrate adjustments to make sure not to change the bitrate too often.
protocol AdjustmentTracker: Actor {
    
    /// Track a bitrate adjustment.
    func trackAdjustment()
    
    /// Check if we are currently in the cooldown, not allowing new adjustments.
    /// - Returns: False if adjustments are allowed, true if we are in the cooldown time window.
    func isInCoolDown() -> Bool
}

actor AdjustmentTrackerImpl: AdjustmentTracker {
    
    private let cooldownDuration: TimeInterval
    private var lastAdjustment: Date?
    
    init(cooldownDuration: TimeInterval) {
        self.cooldownDuration = cooldownDuration
    }
    
    func trackAdjustment() {
        lastAdjustment = Date()
    }
    
    func isInCoolDown() -> Bool {
        guard let lastAdjustment else { return false }
        return Date().timeIntervalSince(lastAdjustment) < cooldownDuration
    }
}
