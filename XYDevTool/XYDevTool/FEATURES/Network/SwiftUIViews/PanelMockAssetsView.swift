//
//  PanelMockAssetsView.swift
//  XYDevTool
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PanelMockAssetsView: View {
    @ObservedObject var mock: NetworkMockController
    
    @State private var editingAsset: MockAsset?
    @State private var isAdding = false
    @State private var statusMessage: String?
    @State private var confirmReplaceImport = false
    @State private var pendingImportURL: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mock 资产")
                    .font(.title2.bold())
                Text("\(mock.assets.count) 条")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("新建") {
                    isAdding = true
                    editingAsset = MockAsset(
                        name: "新资产",
                        method: "GET",
                        path: "/api/example",
                        bodyText: "{\n  \"ok\": true\n}"
                    )
                }
                Button("从当前路由生成") {
                    seedFromRoutes()
                }
                .disabled(mock.routes.isEmpty)
                Button("导出…") {
                    exportAssets()
                }
                .disabled(mock.assets.isEmpty)
                Button("导入…") {
                    chooseImportFile()
                }
            }
            
            Text("资产独立于网络历史，可批量编辑、导入导出。命中时优先于历史回放。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if mock.assets.isEmpty {
                ContentUnavailableView(
                    "暂无 Mock 资产",
                    systemImage: "tray",
                    description: Text("可新建，或从路由「保存为资产」/「从当前路由生成」")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(mock.assets) { asset in
                        assetRow(asset)
                            .contextMenu {
                                Button("编辑…") {
                                    isAdding = false
                                    editingAsset = asset
                                }
                                Button("删除", role: .destructive) {
                                    mock.deleteAsset(id: asset.id)
                                }
                            }
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { mock.assets[$0].id }
                        ids.forEach { mock.deleteAsset(id: $0) }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 420)
        .sheet(item: $editingAsset) { asset in
            MockAssetEditorSheet(
                asset: asset,
                isNew: isAdding,
                onSave: { saved in
                    mock.upsertAsset(saved)
                    statusMessage = "已保存资产「\(saved.name)」"
                    editingAsset = nil
                },
                onCancel: { editingAsset = nil }
            )
        }
        .confirmationDialog(
            "导入方式",
            isPresented: $confirmReplaceImport,
            titleVisibility: .visible
        ) {
            Button("替换全部资产", role: .destructive) {
                importPending(mode: .replace)
            }
            Button("合并到现有资产") {
                importPending(mode: .merge)
            }
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("是否同时应用文件中的 Mock 设置（Query/仅本机/延迟/CORS）？导入时默认会应用。")
        }
    }
    
    private func assetRow(_ asset: MockAsset) -> some View {
        HStack(spacing: 8) {
            Toggle(
                "",
                isOn: Binding(
                    get: { asset.enabled },
                    set: { enabled in
                        var next = asset
                        next.enabled = enabled
                        mock.upsertAsset(next)
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            
            Text(asset.method)
                .font(.caption.monospaced())
                .frame(width: 48, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .lineLimit(1)
                Text(displayPath(asset))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("HTTP \(asset.statusCode)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button("编辑") {
                isAdding = false
                editingAsset = asset
            }
        }
    }
    
    private func displayPath(_ asset: MockAsset) -> String {
        if let query = asset.query, query.isEmpty == false {
            return "\(asset.path)?\(query)"
        }
        return asset.path
    }
    
    private func seedFromRoutes() {
        var added = 0
        for route in mock.routes where route.isEnabled {
            let key = route.routeKey
            if mock.asset(forRouteKey: key) != nil { continue }
            mock.addAsset(from: route)
            added += 1
        }
        statusMessage = added == 0 ? "没有可新增的路由（可能已全部生成）" : "已从路由生成 \(added) 条资产"
    }
    
    private func exportAssets() {
        let panel = NSSavePanel()
        panel.title = "导出 Mock 资产"
        panel.nameFieldStringValue = "network_mock_assets.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try mock.exportAssets(to: url)
            statusMessage = "已导出到 \(url.lastPathComponent)"
        } catch {
            statusMessage = "导出失败：\(error.localizedDescription)"
        }
    }
    
    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.title = "导入 Mock 资产"
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingImportURL = url
        confirmReplaceImport = true
    }
    
    private func importPending(mode: NetworkMockController.AssetImportMode) {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        do {
            try mock.importAssets(from: url, mode: mode, applySettings: true)
            statusMessage = mode == .replace ? "已替换导入资产" : "已合并导入资产"
        } catch {
            statusMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}

private struct MockAssetEditorSheet: View {
    @State var asset: MockAsset
    let isNew: Bool
    let onSave: (MockAsset) -> Void
    let onCancel: () -> Void
    
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isNew ? "新建 Mock 资产" : "编辑 Mock 资产")
                .font(.headline)
            
            HStack {
                Text("名称")
                TextField("名称", text: $asset.name)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("Method")
                Picker("", selection: $asset.method) {
                    Text("GET").tag("GET")
                    Text("POST").tag("POST")
                    Text("PUT").tag("PUT")
                }
                .frame(width: 100)
                
                Text("Path")
                TextField("/api/path", text: $asset.path)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("Query")
                TextField("a=1&b=2（可选）", text: Binding(
                    get: { asset.query ?? "" },
                    set: { asset.query = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("状态码")
                TextField("200", text: Binding(
                    get: { String(asset.statusCode) },
                    set: { asset.statusCode = Int($0) ?? asset.statusCode }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                
                Text("Content-Type")
                TextField("application/json", text: $asset.contentType)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("启用", isOn: $asset.enabled)
                    .toggleStyle(.checkbox)
            }
            
            Text("Body")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $asset.bodyText)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.3))
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack {
                Spacer()
                Button("取消", action: onCancel)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 560, height: 460)
    }
    
    private func save() {
        let path = asset.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.isEmpty == false else {
            errorMessage = "Path 不能为空"
            return
        }
        guard (100...599).contains(asset.statusCode) else {
            errorMessage = "状态码无效"
            return
        }
        let type = asset.contentType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type.isEmpty == false else {
            errorMessage = "Content-Type 不能为空"
            return
        }
        asset.method = asset.method.uppercased()
        asset.path = path.hasPrefix("/") ? path : "/" + path
        asset.contentType = type
        if let query = asset.query {
            asset.query = MockRouteTable.normalizedQuery(from: "?\(query)") ?? query
        }
        onSave(asset)
    }
}
