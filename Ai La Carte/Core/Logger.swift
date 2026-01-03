//
//  Logger.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import os.log

enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"

    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        case .critical:
            return .fault
        }
    }

    var emoji: String {
        switch self {
        case .debug:
            return "[D]"
        case .info:
            return "[I]"
        case .warning:
            return "[W]"
        case .error:
            return "[E]"
        case .critical:
            return "[!]"
        }
    }
}

protocol Logger {
    func log(_ message: String, level: LogLevel, category: String, file: String, function: String, line: Int)
}

extension Logger {
    func debug(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
}

final class AppLogger: Logger {
    static let shared = AppLogger()

    private let subsystem = "com.ailacarte"
    private var loggers: [String: os.Logger] = [:]

    private init() {}

    func log(_ message: String, level: LogLevel, category: String, file: String, function: String, line: Int) {
        let logger = getLogger(for: category)
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"

        #if DEBUG
        let consoleMessage = "\(level.emoji) [\(level.rawValue)] [\(category)] \(formattedMessage)"
        print(consoleMessage)
        #endif

        logger.log(level: level.osLogType, "\(formattedMessage, privacy: .public)")
    }

    private func getLogger(for category: String) -> os.Logger {
        if let existingLogger = loggers[category] {
            return existingLogger
        }

        let newLogger = os.Logger(subsystem: subsystem, category: category)
        loggers[category] = newLogger
        return newLogger
    }
}

// MARK: - Logging Categories

extension AppLogger {
    enum Category {
        static let authentication = "Authentication"
        static let network = "Network"
        static let storage = "Storage"
        static let ui = "UI"
        static let camera = "Camera"
        static let location = "Location"
        static let recommendation = "Recommendation"
        static let session = "Session"
        static let analytics = "Analytics"
    }
}
