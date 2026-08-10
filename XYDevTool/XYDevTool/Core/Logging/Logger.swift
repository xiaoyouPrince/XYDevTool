//
//  Logger.swift
//  XYDevTool
//

import Foundation

enum LogLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case debug
    case info
    case warning
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debug: return "调试"
        case .info: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        }
    }
}

struct LogRecord {
    let level: LogLevel
    let category: String
    let name: String
    let message: String
    let traceID: String?
    let result: String?
    let durationMS: Double?
    let fields: [String: String]
}

protocol LogHandler: AnyObject {
    func isEnabled(for level: LogLevel) -> Bool
    func log(_ record: LogRecord)
}

/// 全局只负责保存当前后端。业务代码不需要知道后端的具体类型。
enum LoggingSystem {
    private static let lock = NSLock()
    private static var handler: LogHandler?

    static func configure(handler: LogHandler?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    static func isEnabled(for level: LogLevel) -> Bool {
        lock.lock()
        let handler = self.handler
        lock.unlock()
        return handler?.isEnabled(for: level) ?? false
    }

    static func emit(_ record: LogRecord) {
        lock.lock()
        let handler = self.handler
        lock.unlock()
        handler?.log(record)
    }
}

/// 业务层唯一需要依赖的轻量日志门面。
struct Logger {
    let category: String

    init(category: String) {
        self.category = category
    }

    func debug(
        _ message: @autoclosure () -> String,
        traceID: String? = nil,
        fields: @autoclosure () -> [String: String] = [:]
    ) {
        write(level: .debug, message: message, traceID: traceID, fields: fields)
    }

    func info(
        _ message: @autoclosure () -> String,
        traceID: String? = nil,
        fields: @autoclosure () -> [String: String] = [:]
    ) {
        write(level: .info, message: message, traceID: traceID, fields: fields)
    }

    func warning(
        _ message: @autoclosure () -> String,
        traceID: String? = nil,
        fields: @autoclosure () -> [String: String] = [:]
    ) {
        write(level: .warning, message: message, traceID: traceID, fields: fields)
    }

    func error(
        _ message: @autoclosure () -> String,
        traceID: String? = nil,
        fields: @autoclosure () -> [String: String] = [:]
    ) {
        write(level: .error, message: message, traceID: traceID, fields: fields)
    }

    func event(
        _ name: String,
        level: LogLevel = .info,
        message: @autoclosure () -> String = "",
        traceID: String? = nil,
        result: String? = nil,
        durationMS: Double? = nil,
        fields: @autoclosure () -> [String: String] = [:]
    ) {
        guard LoggingSystem.isEnabled(for: level) else { return }
        LoggingSystem.emit(
            LogRecord(
                level: level,
                category: category,
                name: name,
                message: message(),
                traceID: traceID,
                result: result,
                durationMS: durationMS,
                fields: fields()
            )
        )
    }

    func begin(_ name: String, fields: [String: String] = [:]) -> LogOperation {
        LogOperation(logger: self, name: name, fields: fields)
    }

    private func write(
        level: LogLevel,
        message: () -> String,
        traceID: String?,
        fields: () -> [String: String]
    ) {
        guard LoggingSystem.isEnabled(for: level) else { return }
        LoggingSystem.emit(
            LogRecord(
                level: level,
                category: category,
                name: "message",
                message: message(),
                traceID: traceID,
                result: nil,
                durationMS: nil,
                fields: fields()
            )
        )
    }
}

final class LogOperation {
    private let logger: Logger
    private let name: String
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private let initialFields: [String: String]
    private let lock = NSLock()
    private var isFinished = false

    init(logger: Logger, name: String, fields: [String: String]) {
        self.logger = logger
        self.name = name
        self.initialFields = fields
    }

    func finish(
        result: String,
        level: LogLevel? = nil,
        fields: [String: String] = [:]
    ) {
        lock.lock()
        guard isFinished == false else {
            lock.unlock()
            return
        }
        isFinished = true
        lock.unlock()

        logger.event(
            name,
            level: level ?? (result == "failure" ? .error : .info),
            result: result,
            durationMS: (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000,
            fields: initialFields.merging(fields) { _, new in new }
        )
    }
}
