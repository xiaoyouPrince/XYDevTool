//
//  LogViewer.swift
//  XYDevTool
//

import AppKit
import SwiftUI

@MainActor
final class LogViewerController: NSObject {
    static let shared = LogViewerController()

    private var window: NSWindow?
    private let logger = Logger(category: "logs")

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let viewModel = LogViewerViewModel()
        let hosting = NSHostingController(rootView: LogViewerView(viewModel: viewModel))
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_080, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "XYDevTool 运行日志"
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = hosting.view
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        window = newWindow

        logger.event("viewer.opened")
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class LogViewerViewModel: ObservableObject {
    @Published private(set) var events: [AppLogEvent] = []
    @Published var selectedEventID: UUID?
    @Published var categoryFilter = "all"
    @Published var levelFilter = "all"
    @Published var searchText = ""
    @Published var isLoading = false

    var filteredEvents: [AppLogEvent] {
        events.filter { event in
            let matchesCategory = categoryFilter == "all" || event.category == categoryFilter
            let matchesLevel = levelFilter == "all" || event.level.rawValue == levelFilter
            let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = search.isEmpty
                || event.name.lowercased().contains(search)
                || event.metadata.contains { key, value in
                    key.lowercased().contains(search) || value.lowercased().contains(search)
                }
            return matchesCategory && matchesLevel && matchesSearch
        }
    }

    var selectedEvent: AppLogEvent? {
        guard let selectedEventID else { return nil }
        return events.first { $0.id == selectedEventID }
    }

    var categories: [String] {
        Array(Set(events.map(\.category))).sorted()
    }

    var summary: AppLogSummary {
        AppLogSummary.make(from: filteredEvents)
    }

    init() {
        reload()
    }

    func reload() {
        isLoading = true
        LocalLogService.shared.loadEvents { [weak self] events in
            self?.events = events
            self?.isLoading = false
            if let selected = self?.selectedEventID,
               events.contains(where: { $0.id == selected }) == false {
                self?.selectedEventID = nil
            }
        }
    }

    func clear() {
        LocalLogService.shared.clearLogs { [weak self] in
            self?.reload()
        }
    }
}

struct LogViewerView: View {
    @ObservedObject var viewModel: LogViewerViewModel
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            filterBar
            Divider()

            HSplitView {
                eventList
                    .frame(minWidth: 580)
                eventDetail
                    .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .confirmationDialog(
            "确定清除全部运行日志？",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除日志", role: .destructive) {
                viewModel.clear()
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 24) {
            summaryItem(title: "事件", value: String(viewModel.summary.eventCount))
            summaryItem(title: "会话", value: String(viewModel.summary.sessionCount))
            summaryItem(title: "失败", value: String(viewModel.summary.failureCount))
            summaryItem(
                title: "平均耗时",
                value: viewModel.summary.averageDurationMS.map { String(format: "%.0f ms", $0) } ?? "—"
            )
            Spacer()
            Label("请求与响应日志经过安全过滤，仅保存在本机", systemImage: "lock.doc")
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.isLoading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("模块", selection: $viewModel.categoryFilter) {
                Text("全部模块").tag("all")
                ForEach(viewModel.categories, id: \.self) { category in
                    Text(Self.categoryTitle(category)).tag(category)
                }
            }
            .frame(width: 180)

            Picker("级别", selection: $viewModel.levelFilter) {
                Text("全部级别").tag("all")
                ForEach(LogLevel.allCases) { level in
                    Text(level.title).tag(level.rawValue)
                }
            }
            .frame(width: 150)

            TextField("搜索事件或运行数据", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            Button("刷新") { viewModel.reload() }
            Button("在 Finder 中显示") { LocalLogService.shared.revealLogDirectory() }
            Button("清除") { showClearConfirmation = true }
        }
        .padding(12)
    }

    private var eventList: some View {
        List(viewModel.filteredEvents, selection: $viewModel.selectedEventID) { event in
            HStack(spacing: 10) {
                Text(Self.timestampFormatter.string(from: event.timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 145, alignment: .leading)

                Text(Self.categoryTitle(event.category))
                    .font(.caption)
                    .frame(width: 90, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(event.level.title)
                        if let result = event.result {
                            Text(Self.resultTitle(result))
                        }
                        if let duration = event.durationMS {
                            Text(String(format: "%.0f ms", duration))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(event.level == .error ? Color.red : Color.secondary)
                }
                Spacer()
            }
            .tag(event.id)
        }
        .overlay {
            if viewModel.filteredEvents.isEmpty && viewModel.isLoading == false {
                ContentUnavailableView("暂无日志", systemImage: "doc.text.magnifyingglass")
            }
        }
    }

    @ViewBuilder
    private var eventDetail: some View {
        if let event = viewModel.selectedEvent {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    detailRow("事件", event.name)
                    detailRow("时间", Self.timestampFormatter.string(from: event.timestamp))
                    detailRow("模块", Self.categoryTitle(event.category))
                    detailRow("级别", event.level.title)
                    detailRow("会话", event.sessionID.uuidString)
                    detailRow("顺序", String(event.sequence))
                    if let result = event.result {
                        detailRow("结果", Self.resultTitle(result))
                    }
                    if let duration = event.durationMS {
                        detailRow("耗时", String(format: "%.2f ms", duration))
                    }

                    if event.metadata.isEmpty == false {
                        Divider()
                        Text("运行数据").font(.headline)
                        ForEach(event.metadata.keys.sorted(), id: \.self) { key in
                            detailRow(key, event.metadata[key] ?? "")
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("选择一条日志查看详情", systemImage: "doc.text")
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private static func categoryTitle(_ category: String) -> String {
        switch category {
        case "app": return "App"
        case "navigation": return "使用路径"
        case "network": return "网络请求"
        case "json_formatter": return "JSON 格式化"
        case "json2model": return "JSON 转 Model"
        case "app_icon": return "AppIcon"
        case "custom_server": return "自定义服务器"
        case "image_inspector": return "图片查看器"
        case "update": return "版本检查"
        case "logs": return "日志工具"
        default: return category
        }
    }

    private static func resultTitle(_ result: String) -> String {
        switch result {
        case "success": return "成功"
        case "failure": return "失败"
        case "cancelled": return "取消"
        default: return result
        }
    }
}
