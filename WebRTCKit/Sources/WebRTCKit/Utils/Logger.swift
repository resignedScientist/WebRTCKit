import os
import Foundation

/// Enumeration representing different categories for logging purposes.
public enum LoggerCategory: String, Sendable {
    
    /// Default logging category.
    case `default`
    
    /// Logging category for user interface related messages.
    case userInterface
}

public enum LogType: Sendable {
    
    /// Debug messages; usually for testing
    case debug
    
    /// There was an error.
    case error
    
    /// There is some serious bug in the code.
    case fault
    
    /// Some kind of information, status update, etc.
    case info
}

public protocol LoggerDelegate: AnyObject, Sendable {
    
    func didLogMessage(
        type: LogType,
        caller: String,
        category: LoggerCategory,
        message: String
    )
}

/// A class responsible for logging messages with different severity levels.
/// This logger uses Apple's unified logging system.
final class Logger: Sendable {
    
    private var logLevel: LogLevel {
        DIContainer.Instance.logLevel!
    }
    
    private var delegate: LoggerDelegate? {
        DIContainer.Instance.loggerDelegate
    }
    
    private let log: OSLog
    private let caller: String
    private let category: LoggerCategory
    
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
        self.category = category
    }
    
    /// Logs a debug message.
    /// - Parameter message: The message to log as debug.
    func debug(_ message: String) {
        
        // do not log if log level does not match
        guard logLevel >= .debug else { return }
        
        let caller = self.caller
        
        // print log message in the console
        os_log(.debug, log: log, "🪲 [\(caller)] \(message)")
        
        // update our delegate if it exists
        delegate?.didLogMessage(
            type: .debug,
            caller: caller,
            category: category,
            message: message
        )
    }
    
    /// Logs an informational message.
    /// - Parameter message: The message to log as information.
    func info(_ message: String) {
        
        // do not log if log level does not match
        guard logLevel >= .debug else { return }
        
        let caller = self.caller
        
        // print log message in the console
        os_log(.info, log: log, "ℹ️ [\(caller)] \(message)")
        
        // update our delegate if it exists
        delegate?.didLogMessage(
            type: .info,
            caller: caller,
            category: category,
            message: message
        )
    }
    
    /// Logs an error message.
    /// - Parameter message: The message to log as an error.
    func error(_ message: String) {
        
        // do not log if log level does not match
        guard logLevel >= .error else { return }
        
        let caller = self.caller
        
        // print log message in the console
        os_log(.error, log: log, "⚠️ [\(caller)] \(message)")
        
        // update our delegate if it exists
        delegate?.didLogMessage(
            type: .error,
            caller: caller,
            category: category,
            message: message
        )
    }
    
    /// Logs a fault message, which indicates a critical failure.
    /// - Parameter message: The message to log as a fault.
    func fault(_ message: String) {
        
        // do not log if log level does not match
        guard logLevel >= .error else { return }
        
        let caller = self.caller
        
        // print log message in the console
        os_log(.fault, log: log, "❌ [\(caller)] \(message)")
        
        // update our delegate if it exists
        delegate?.didLogMessage(
            type: .fault,
            caller: caller,
            category: category,
            message: message
        )
    }
}
