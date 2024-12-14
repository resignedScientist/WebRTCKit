import os
import Foundation

/// Enumeration representing different categories for logging purposes.
enum LoggerCategory: String {
    
    /// Default logging category.
    case `default`
    
    /// Logging category for user interface related messages.
    case userInterface
}

/// A class responsible for logging messages with different severity levels.
/// This logger uses Apple's unified logging system.
final class Logger: Sendable {
    
    private let log: OSLog
    private let caller: String
    
    /// Initializes the logger with a caller description and a category.
    /// - Parameters:
    ///   - caller: The description of the caller, e.g. the class.
    ///   - category: The category for the log messages.
    init(caller: String, category: LoggerCategory = .default) {
        self.caller = caller
        self.log = OSLog(
            subsystem: Bundle.main.bundleIdentifier ?? "unknown",
            category: category.rawValue
        )
    }
    
    /// Logs a debug message.
    /// - Parameter message: The message to log as debug.
    func debug(_ message: String) {
        let caller = self.caller
        os_log(.debug, log: log, "🪲 [\(caller)] \(message)")
    }
    
    /// Logs an informational message.
    /// - Parameter message: The message to log as information.
    func info(_ message: String) {
        let caller = self.caller
        os_log(.info, log: log, "ℹ️ [\(caller)] \(message)")
    }
    
    /// Logs an error message.
    /// - Parameter message: The message to log as an error.
    func error(_ message: String) {
        let caller = self.caller
        os_log(.error, log: log, "⚠️ [\(caller)] \(message)")
    }
    
    /// Logs a fault message, which indicates a critical failure.
    /// - Parameter message: The message to log as a fault.
    func fault(_ message: String) {
        let caller = self.caller
        os_log(.fault, log: log, "❌ [\(caller)] \(message)")
    }
}
