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

        AppLogger.shared.track(category: .logs, name: "log_viewer_opened")
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
            let matchesCategory = categoryFilter == "all" || event.category.rawValue == categoryFilter
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

    var summary: AppLogSummary {
        AppLogSummary.make(from: filteredEvents)
    }

    init() {
        reload()
    }

    func reload() {
        isLoading = true
        AppLogger.shared.loadEvents { [weak self] events in
            self?.events = events
            self?.isLoading = false
            if let selected = self?.selectedEventID,
               events.contains(where: { $0.id == selected }) == false {
                self?.selectedEventID = nil
            }
        }
    }

    func clear() {
        AppLogger.shared.clearLogs { [weak self] in
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
            Label("包含完整请求与响应，仅保存在本机", systemImage: "lock.doc")
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
                ForEach(AppLogCategory.allCases) { category in
                    Text(category.title).tag(category.rawValue)
                }
            }
            .frame(width: 180)

            Picker("级别", selection: $viewModel.levelFilter) {
                Text("全部级别").tag("all")
                ForEach(AppLogLevel.allCases) { level in
                    Text(level.title).tag(level.rawValue)
                }
            }
            .frame(width: 150)

            TextField("搜索事件或运行数据", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            Button("刷新") { viewModel.reload() }
            Button("在 Finder 中显示") { AppLogger.shared.revealLogDirectory() }
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

                Text(event.category.title)
                    .font(.caption)
                    .frame(width: 90, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(event.level.title)
                        if let result = event.result {
                            Text(result.title)
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
                    detailRow("模块", event.category.title)
                    detailRow("级别", event.level.title)
                    detailRow("会话", event.sessionID.uuidString)
                    detailRow("顺序", String(event.sequence))
                    if let result = event.result {
                        detailRow("结果", result.title)
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
}
