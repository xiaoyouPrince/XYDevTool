//
//  PanelMockView.swift
//  XYDevTool
//

import SwiftUI

struct PanelMockView: View {
    @EnvironmentObject private var dataModel: NetworkDataModel
    @ObservedObject var mock: NetworkMockController
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            configRow
            warning
            routeSummary
            logSection
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            mock.refreshLocalIPs()
            mock.reloadRoutes(from: dataModel.historyRoots)
        }
    }
    
    private var header: some View {
        HStack {
            Text("Mock 服务")
                .font(.title2.bold())
            Spacer()
            Text(mock.statusText)
                .foregroundStyle(mock.isRunning ? Color.green : Color.secondary)
                .font(.caption)
        }
    }
    
    private var configRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("端口")
                TextField("18080", text: $mock.portText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .disabled(mock.isRunning)
                
                Text("局域网 IP")
                Picker("", selection: $mock.selectedIP) {
                    ForEach(mock.localIPs, id: \.self) { ip in
                        Text(ip).tag(ip)
                    }
                }
                .frame(width: 160)
                .disabled(mock.localIPs.isEmpty)
                
                Button("刷新 IP") {
                    mock.refreshLocalIPs()
                }
                
                Spacer()
                
                if mock.isRunning {
                    Button("停止") {
                        mock.stop()
                    }
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button("启动") {
                        mock.start(with: dataModel.historyRoots)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            
            HStack(spacing: 8) {
                Text("Base URL")
                    .foregroundStyle(.secondary)
                Text(mock.baseURL)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Button("复制") {
                    mock.copyBaseURL()
                }
                Spacer()
            }
            
            if let error = mock.lastError, error.isEmpty == false {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    private var warning: some View {
        Label(
            "调试用途：开启后会向局域网暴露当前历史中的接口响应数据",
            systemImage: "exclamationmark.triangle"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    private var routeSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("路由 \(mock.routes.count) 条")
                    .font(.headline)
                if mock.conflictCount > 0 {
                    Text("冲突 \(mock.conflictCount)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            
            if mock.routes.isEmpty {
                Text("暂无可用路由。请先对接口 Submit 并保存带响应的历史记录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List(mock.routes) { route in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(route.method)
                            .font(.caption.monospaced())
                            .frame(width: 48, alignment: .leading)
                        Text(route.path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(route.sourceName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if route.isConflict {
                            Text("冲突")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 140, maxHeight: 180)
            }
        }
    }
    
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("访问日志")
                .font(.headline)
            
            if mock.accessLogs.isEmpty {
                Text("尚无访问")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List(mock.accessLogs) { log in
                    HStack(spacing: 8) {
                        Text(timeFormatter.string(from: log.timestamp))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(log.method)
                            .font(.caption.monospaced())
                            .frame(width: 48, alignment: .leading)
                        Text(log.path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(log.hitName ?? "未命中")
                            .foregroundStyle(log.hitName == nil ? Color.orange : Color.secondary)
                            .lineLimit(1)
                        Text(String(log.statusCode))
                            .font(.caption.monospaced())
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 120, maxHeight: 160)
            }
        }
    }
}
