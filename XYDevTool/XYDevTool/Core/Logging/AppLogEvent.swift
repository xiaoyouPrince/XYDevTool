//
//  AppLogEvent.swift
//  XYDevTool
//

import Foundation

/// 本地 JSONL 文件使用的持久化模型。
struct AppLogEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let sessionID: UUID
    let sequence: Int
    let level: LogLevel
    let category: String
    let name: String
    let message: String
    let traceID: String?
    let result: String?
    let durationMS: Double?
    let metadata: [String: String]
    let appVersion: String
    let buildVersion: String
}

struct AppLogSummary {
    let eventCount: Int
    let sessionCount: Int
    let failureCount: Int
    let averageDurationMS: Double?

    static func make(from events: [AppLogEvent]) -> AppLogSummary {
        let durations = events.compactMap(\.durationMS)
        let average = durations.isEmpty
            ? nil
            : durations.reduce(0, +) / Double(durations.count)

        return AppLogSummary(
            eventCount: events.count,
            sessionCount: Set(events.map(\.sessionID)).count,
            failureCount: events.filter { $0.result == "failure" || $0.level == .error }.count,
            averageDurationMS: average
        )
    }
}
