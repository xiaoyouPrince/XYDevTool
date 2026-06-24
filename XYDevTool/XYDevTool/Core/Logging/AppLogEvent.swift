//
//  AppLogEvent.swift
//  XYDevTool
//

import Foundation

enum AppLogLevel: String, Codable, CaseIterable, Identifiable, Hashable {
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

enum AppLogCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case app
    case navigation
    case network
    case jsonFormatter = "json_formatter"
    case json2Model = "json2model"
    case appIcon = "app_icon"
    case customServer = "custom_server"
    case imageInspector = "image_inspector"
    case update
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "App"
        case .navigation: return "使用路径"
        case .network: return "网络请求"
        case .jsonFormatter: return "JSON 格式化"
        case .json2Model: return "JSON 转 Model"
        case .appIcon: return "AppIcon"
        case .customServer: return "自定义服务器"
        case .imageInspector: return "图片查看器"
        case .update: return "版本检查"
        case .logs: return "日志工具"
        }
    }
}

enum AppLogResult: String, Codable, Hashable {
    case success
    case failure
    case cancelled

    var title: String {
        switch self {
        case .success: return "成功"
        case .failure: return "失败"
        case .cancelled: return "取消"
        }
    }
}

struct AppLogEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let sessionID: UUID
    let sequence: Int
    let level: AppLogLevel
    let category: AppLogCategory
    let name: String
    let result: AppLogResult?
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
            failureCount: events.filter { $0.result == .failure || $0.level == .error }.count,
            averageDurationMS: average
        )
    }
}
