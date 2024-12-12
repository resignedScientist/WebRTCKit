import os
import Foundation

enum LoggerCategory: String {
    case `default`
    case userInterface
}

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
    
    func debug(_ message: String) {
        let caller = self.caller
        os_log(.debug, log: log, "🪲 [\(caller)] \(message)")
    }
    
    func info(_ message: String) {
        let caller = self.caller
        os_log(.info, log: log, "ℹ️ [\(caller)] \(message)")
    }
    
    func error(_ message: String) {
        let caller = self.caller
        os_log(.error, log: log, "⚠️ [\(caller)] \(message)")
    }
    
    func fault(_ message: String) {
        let caller = self.caller
        os_log(.fault, log: log, "❌ [\(caller)] \(message)")
    }
}
