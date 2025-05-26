public enum LogLevel: UInt8, Sendable, Comparable {
    
    /// Do not log anything.
    case none = 0
    
    /// Only log errors.
    case error = 1
    
    /// Log errors and info.
    case info = 2
    
    /// Log errors, info and debug information.
    case debug = 3
    
    /// Log everything, icluding verbose WebRTC logging.
    case verbose = 4
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
