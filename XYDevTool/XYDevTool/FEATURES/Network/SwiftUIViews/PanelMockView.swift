//
//  PanelMockView.swift
//  XYDevTool
//

import SwiftUI

struct PanelMockView: View {
    @EnvironmentObject private var dataModel: NetworkDataModel
    @ObservedObject var mock: NetworkMockController
    
    @State private var conflictRoute: MockRoute?
    @State private var overrideRoute: MockRoute?
    @State private var showAssets = false
    @State private var showPassthroughExtras = false
    @State private var editingExtractRule: MockExtractRule?
    @State private var headerTemplateDraft = ""
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            configRow
            passthroughSection
            warning
            routeSummary
            logSection
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            mock.refreshLocalIPs()
            mock.reloadRoutes(from: dataModel.historyRoots)
        }
        .sheet(item: $conflictRoute) { route in
            MockConflictSheet(route: route, mock: mock)
        }
        .sheet(item: $overrideRoute) { route in
            MockOverrideSheet(route: route, mock: mock)
        }
        .sheet(isPresented: $showAssets) {
            PanelMockAssetsView(mock: mock)
        }
    }
    
    private var header: some View {
        HStack {
            Text("Mock 服务")
                .font(.title2.bold())
            Button("资产…") {
                showAssets = true
            }
            if mock.assets.isEmpty == false {
                Text("\(mock.assets.count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
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
                .disabled(mock.localIPs.isEmpty || mock.localhostOnly)
                
                Button("刷新 IP") {
                    mock.refreshLocalIPs()
                }
                .disabled(mock.localhostOnly)
                
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
            
            HStack(spacing: 16) {
                Toggle("匹配 Query", isOn: Binding(
                    get: { mock.matchQuery },
                    set: { mock.setMatchQuery($0) }
                ))
                .toggleStyle(.checkbox)
                .help("开启后 Method+Path+Query 才算命中；关闭则忽略 query")
                
                Toggle("仅本机", isOn: Binding(
                    get: { mock.localhostOnly },
                    set: { mock.setLocalhostOnly($0) }
                ))
                .toggleStyle(.checkbox)
                .help("只监听 127.0.0.1，局域网不可访问；切换时若正在运行会自动重启")
                
                Toggle("CORS", isOn: Binding(
                    get: { mock.corsEnabled },
                    set: { mock.setCorsEnabled($0) }
                ))
                .toggleStyle(.checkbox)
                .help("是否返回 Access-Control-Allow-Origin: *")
                
                HStack(spacing: 4) {
                    Text("延迟")
                    TextField(
                        "0",
                        text: Binding(
                            get: { String(mock.delayMS) },
                            set: { mock.setDelayMS(Int($0) ?? 0) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    Text("ms")
                        .foregroundStyle(.secondary)
                }
                .help("响应前额外等待，上限 30000ms")
                
                Spacer()
            }
            .font(.caption)
            
            if let error = mock.lastError, error.isEmpty == false {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    private var passthroughSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Toggle("透传", isOn: Binding(
                    get: { mock.passthroughEnabled },
                    set: { mock.setPassthroughEnabled($0) }
                ))
                .toggleStyle(.checkbox)
                .help("开启后：未命中路由将转发到上游并写入历史；已命中默认仍走缓存，可在路由行改为透传")
                
                Text("上游")
                    .foregroundStyle(.secondary)
                TextField(
                    "https://api.example.com",
                    text: Binding(
                        get: { mock.upstreamBaseURL },
                        set: { mock.setUpstreamBaseURL($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220)
                
                HStack(spacing: 4) {
                    Text("超时")
                    TextField(
                        "20000",
                        text: Binding(
                            get: { String(mock.passthroughTimeoutMS) },
                            set: { mock.setPassthroughTimeoutMS(Int($0) ?? 20_000) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    Text("ms")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(showPassthroughExtras ? "收起高级" : "高级…") {
                    showPassthroughExtras.toggle()
                    if showPassthroughExtras {
                        headerTemplateDraft = mock.outboundHeaderTemplates
                            .map { "\($0.key)=\($0.value)" }
                            .sorted()
                            .joined(separator: "\n")
                    }
                }
                .font(.caption)
            }
            .font(.caption)
            
            HStack(spacing: 12) {
                Text("命中策略")
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { mock.globalHitMode },
                    set: { mock.setGlobalHitMode($0) }
                )) {
                    ForEach(MockRouteMode.allCases) { mode in
                        Text(mode == .cache ? "全部缓存" : "全部透传").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                
                Text(mock.hitPolicySummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if mock.routeModeOverrideCount > 0 {
                    Button("清除逐条覆盖") {
                        mock.clearRouteModeOverrides()
                    }
                    .font(.caption)
                }
                
                Spacer()
            }
            .font(.caption)
            .help("切换后手机无需改 host：已命中路由统一走缓存或透传；未命中仍由上方「透传」开关决定")
            
            if showPassthroughExtras {
                HStack(spacing: 16) {
                    Toggle("写回历史", isOn: Binding(
                        get: { mock.passthroughWriteBack },
                        set: { mock.setPassthroughWriteBack($0) }
                    ))
                    .toggleStyle(.checkbox)
                    
                    Toggle("非 2xx 也留存", isOn: Binding(
                        get: { mock.passthroughSaveNon2xx },
                        set: { mock.setPassthroughSaveNon2xx($0) }
                    ))
                    .toggleStyle(.checkbox)
                    
                    Spacer()
                }
                .font(.caption)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("出站 Header 模板（每行 Name={{var}}，透传时覆盖/追加）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $headerTemplateDraft)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 56)
                        .border(Color.secondary.opacity(0.25))
                    Button("应用 Header 模板") {
                        applyHeaderTemplates()
                    }
                    .font(.caption)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("响应抽变量")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button("新增规则") {
                            editingExtractRule = MockExtractRule(jsonPath: "data.token", variableKey: "token")
                        }
                        .font(.caption)
                    }
                    if mock.extractRules.isEmpty {
                        Text("例如登录响应 data.token → 变量 token，供出站 Header 使用。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(mock.extractRules) { rule in
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { rule.enabled },
                                    set: {
                                        var next = rule
                                        next.enabled = $0
                                        mock.upsertExtractRule(next)
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                                Text("\(rule.jsonPath) → \(rule.variableKey)")
                                    .font(.caption.monospaced())
                                if rule.routeKey.isEmpty == false {
                                    Text("(\(rule.routeKey))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("编辑") { editingExtractRule = rule }
                                    .font(.caption2)
                                Button("删除", role: .destructive) {
                                    mock.deleteExtractRule(id: rule.id)
                                }
                                .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .sheet(item: $editingExtractRule) { rule in
            ExtractRuleEditorSheet(rule: rule) { saved in
                mock.upsertExtractRule(saved)
                editingExtractRule = nil
            } onCancel: {
                editingExtractRule = nil
            }
        }
    }
    
    private func applyHeaderTemplates() {
        var map: [String: String] = [:]
        for line in headerTemplateDraft.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false,
                  let eq = trimmed.firstIndex(of: "=") else { continue }
            let name = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            guard name.isEmpty == false else { continue }
            map[name] = value
        }
        mock.setOutboundHeaderTemplates(map)
    }
    
    private var warning: some View {
        Label(
            mock.passthroughEnabled
                ? "透传开启：未命中将转发到上游真实环境并写入「透传捕获」历史；请确认上游地址无误。"
                : (mock.localhostOnly
                    ? "仅本机模式：只有本机可访问。右键路由可复制或自定义返回。"
                    : "调试用途：开启后会向局域网暴露当前历史中的接口响应数据。右键路由可复制或自定义返回。"),
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
                Text(
                    mock.passthroughEnabled
                        ? "暂无缓存路由。开启透传后，客户端请求会自动录制到历史。"
                        : "暂无可用路由。请先对接口 Submit，或开启透传从真实上游录制。"
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List(mock.routes) { route in
                    routeRow(route)
                        .contextMenu {
                            Button("复制路径") {
                                mock.copyPath(for: route)
                            }
                            Button("复制完整 URL") {
                                mock.copyFullURL(for: route)
                            }
                            Button("复制 curl") {
                                mock.copyCurl(for: route)
                            }
                            Divider()
                            Button("模式：缓存") {
                                mock.setRouteMode(route, mode: .cache)
                            }
                            Button("模式：透传") {
                                mock.setRouteMode(route, mode: .passthrough)
                            }
                            Divider()
                            if route.isConflict {
                                Button("选择冲突来源…") {
                                    conflictRoute = route
                                }
                            }
                            Button("自定义返回…") {
                                overrideRoute = route
                            }
                            Button("保存为资产") {
                                mock.addAsset(from: route)
                            }
                            if route.hasCustomOverride || route.hasAsset {
                                Button("清除自定义返回", role: .destructive) {
                                    mock.clearOverride(routeKey: route.routeKey)
                                    if let asset = mock.asset(forRouteKey: route.routeKey) {
                                        mock.deleteAsset(id: asset.id)
                                    }
                                }
                            }
                        }
                }
                .listStyle(.inset)
                .frame(minHeight: 160, maxHeight: 200)
            }
        }
    }
    
    private func routeRow(_ route: MockRoute) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle("", isOn: Binding(
                get: { route.isEnabled },
                set: { mock.setRouteEnabled(route, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            
            Text(route.method)
                .font(.caption.monospaced())
                .frame(width: 48, alignment: .leading)
                .foregroundStyle(route.isEnabled ? Color.primary : Color.secondary)
            
            Text(route.displayPath)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .foregroundStyle(route.isEnabled ? Color.primary : Color.secondary)
            
            Picker("", selection: Binding(
                get: { mock.routeMode(for: route) },
                set: { mock.setRouteMode(route, mode: $0) }
            )) {
                ForEach(MockRouteMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 72)
            .disabled(route.isEnabled == false)
            
            Spacer()
            
            Text(route.sourceName)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            if route.hasAsset || route.isAssetOnly {
                Text(route.isAssetOnly ? "仅资产" : "资产")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            } else if route.hasCustomOverride {
                Text("自定义")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            
            if route.isConflict {
                Button("冲突") {
                    conflictRoute = route
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
        .opacity(route.isEnabled ? 1 : 0.55)
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
                    VStack(alignment: .leading, spacing: 2) {
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
                        if let hint = log.hint {
                            Text(hint)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.leading, 116)
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 120, maxHeight: 160)
            }
        }
    }
}

private struct MockConflictSheet: View {
    let route: MockRoute
    @ObservedObject var mock: NetworkMockController
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择 Mock 来源")
                .font(.headline)
            Text("\(route.method) \(route.displayPath)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            
            Text("同 Method+Path（及 Query，若已开启）有多条历史时，可指定当前生效的一条。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            List(route.candidates) { candidate in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.sourceName)
                        Text("HTTP \(candidate.statusCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if candidate.sourceId == route.selectedSourceId {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    mock.selectConflictWinner(routeKey: route.routeKey, sourceId: candidate.sourceId)
                    dismiss()
                }
            }
            
            HStack {
                Spacer()
                Button("关闭") { dismiss() }
            }
        }
        .padding(16)
        .frame(width: 420, height: 320)
    }
}

private struct MockOverrideSheet: View {
    let route: MockRoute
    @ObservedObject var mock: NetworkMockController
    @Environment(\.dismiss) private var dismiss
    
    @State private var statusText: String = "200"
    @State private var bodyText: String = "{\n\n}"
    @State private var contentType: String = "application/json"
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自定义返回")
                .font(.headline)
            Text("\(route.method) \(route.displayPath)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("仅影响 Mock 回放，不会修改网络历史中的真实响应。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("状态码")
                TextField("200", text: $statusText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("Content-Type")
                TextField("application/json", text: $contentType)
                    .textFieldStyle(.roundedBorder)
            }
            
            Text("Body")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $bodyText)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.3))
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack {
                if mock.override(for: route.routeKey) != nil {
                    Button("清除自定义", role: .destructive) {
                        mock.clearOverride(routeKey: route.routeKey)
                        dismiss()
                    }
                }
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 520, height: 420)
        .onAppear(perform: loadInitial)
    }
    
    private func loadInitial() {
        if let existing = mock.override(for: route.routeKey) {
            statusText = String(existing.statusCode)
            bodyText = existing.bodyText
            contentType = existing.contentType
            return
        }
        if let active = route.activeCandidate,
           let text = String(data: active.body, encoding: .utf8) {
            statusText = String(active.statusCode)
            bodyText = text
            contentType = active.contentType
        }
    }
    
    private func save() {
        guard let code = Int(statusText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (100...599).contains(code) else {
            errorMessage = "状态码无效"
            return
        }
        let type = contentType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type.isEmpty == false else {
            errorMessage = "Content-Type 不能为空"
            return
        }
        mock.saveOverride(
            routeKey: route.routeKey,
            override: MockRouteOverride(
                statusCode: code,
                bodyText: bodyText,
                contentType: type
            )
        )
        dismiss()
    }
}

private struct ExtractRuleEditorSheet: View {
    @State var rule: MockExtractRule
    let onSave: (MockExtractRule) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("响应抽变量")
                .font(.headline)
            TextField("JSON 路径（如 data.token）", text: $rule.jsonPath)
                .textFieldStyle(.roundedBorder)
            TextField("变量名", text: $rule.variableKey)
                .textFieldStyle(.roundedBorder)
            TextField("限定 routeKey（可空=全部）", text: $rule.routeKey)
                .textFieldStyle(.roundedBorder)
            Toggle("启用", isOn: $rule.enabled)
                .toggleStyle(.checkbox)
            HStack {
                Spacer()
                Button("取消", action: onCancel)
                Button("保存") {
                    onSave(rule)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    rule.jsonPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || rule.variableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
