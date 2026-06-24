//
//  PanelSettingsView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/9/27.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    @Environment(NetworkEditorStore.self) private var editorStore
    @Environment(\.presentationMode) var presentationMode
    
    private var hasSelectedRequest: Bool {
        dataModel.isSelectedRequest
    }
    
    private var variablePreview: (rows: [NetworkVariablePreview], error: String?) {
        dataModel.variableResolutionPreview()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    variableSection
                    globalPreScriptSection
                    preScriptSelectionSection
                    globalScriptSection
                    postScriptSelectionSection
                }
                .padding()
            }
            
            if dataModel.variables.isEmpty {
                EmptyView()
            }
            
            HStack {
                Button("导入配置") {
                    importConfigs()
                }
                Button("导出配置") {
                    exportConfigs()
                }
                Spacer()
                Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(NetworkTheme.panelBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NetworkTheme.panelBorder)
                    .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var variableSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("变量设置")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("新增变量") {
                    dataModel.addVariable()
                }
            }
            
            if dataModel.variables.isEmpty {
                Text("暂无变量，点击右上角“新增变量”开始配置")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach($dataModel.variables) { $variable in
                        HStack(spacing: 10) {
                            TextField("key", text: $variable.key)
                                .textFieldStyle(.roundedBorder)
                            Text(":")
                                .foregroundStyle(.secondary)
                            TextField("value", text: $variable.value)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                dataModel.removeVariable(id: variable.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("最终解析预览")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let error = variablePreview.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if variablePreview.rows.isEmpty {
                        Text("暂无可预览变量")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(variablePreview.rows) { row in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(row.key)
                                    .font(.system(.caption, design: .monospaced))
                                Text("=>")
                                    .foregroundStyle(.secondary)
                                Text(row.resolvedValue)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(NetworkTheme.sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(NetworkTheme.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var postScriptSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前接口后置脚本")
                .font(.title3)
                .fontWeight(.semibold)
            Text("从全局后置脚本库中勾选当前接口要执行的脚本（可多选）。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if hasSelectedRequest == false {
                Text("未选中历史请求，无法绑定脚本。请先在左侧选择一个请求。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else if dataModel.globalPostScripts.isEmpty {
                Text("暂无全局后置脚本，请先在上方“全局后置脚本库”新增。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(dataModel.globalPostScripts) { script in
                        Toggle(isOn: bindingForPostScriptSelection(script.id.uuidString)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(script.name.isEmpty ? "未命名脚本" : script.name)
                                Text(script.command)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
        .padding(12)
        .background(NetworkTheme.sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(NetworkTheme.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var preScriptSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前接口前置脚本")
                .font(.title3)
                .fontWeight(.semibold)
            Text("从全局前置脚本库中选择一条脚本，在发请求前执行（单选）。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if hasSelectedRequest == false {
                Text("未选中历史请求，无法绑定脚本。请先在左侧选择一个请求。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else if dataModel.globalPreScripts.isEmpty {
                Text("暂无全局前置脚本，请先在上方“全局前置脚本库”新增。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                Picker("前置脚本", selection: preScriptSelectionBinding) {
                    Text("无").tag(Optional<String>.none)
                    ForEach(dataModel.globalPreScripts) { script in
                        Text(script.name.isEmpty ? "未命名脚本" : script.name)
                            .tag(Optional(script.id.uuidString))
                    }
                }
                .pickerStyle(.radioGroup)
                
                if let selectedID = editorStore.selectedPreScriptIDForCurrent,
                   let script = dataModel.globalPreScripts.first(where: { $0.id.uuidString == selectedID }) {
                    Text(script.command)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(NetworkTheme.sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(NetworkTheme.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var globalPreScriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("全局前置脚本库")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("新增脚本") {
                    dataModel.addGlobalPreScript()
                }
            }
            
            Text("脚本命令支持直接写 shell 或指定外部路径（示例：swift ~/sign.swift）。App 通过环境变量 XYDEV_PRE_REQUEST_JSON 注入请求 JSON（url/method/headersText/parametersText，{{变量}} 已替换；header/body 可为空）。stdout 输出一行 JSON：POST 用 parametersText 保序；GET 返回完整 url；代发 {\"response\":\"...\"}；失败 {\"error\":\"...\"}。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if dataModel.globalPreScripts.isEmpty {
                Text("暂无全局前置脚本，点击右上角“新增脚本”开始配置。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach($dataModel.globalPreScripts) { $script in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("脚本名称（例如：接口签名）", text: $script.name)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    dataModel.removeGlobalPreScript(id: script.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            CustomTextEditor(text: $script.command)
                                .frame(minHeight: 90)
                                .padding(6)
                                .background(NetworkTheme.panelBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(NetworkTheme.panelBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(10)
                        .background(NetworkTheme.panelBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(NetworkTheme.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(12)
        .background(NetworkTheme.sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(NetworkTheme.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var globalScriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("全局后置脚本库")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("新增脚本") {
                    dataModel.addGlobalPostScript()
                }
            }
            
            Text("脚本命令模板支持直接写 $1/$2（示例：swift /Users/quxiaoyou/Desktop/Shell/swift2.swift \"$1\" \"$2\"）。其中 $1=响应文本，$2=当前变量JSON。输出支持 JSON 或多行 key=value。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if dataModel.globalPostScripts.isEmpty {
                Text("暂无全局脚本，点击右上角“新增脚本”开始配置。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach($dataModel.globalPostScripts) { $script in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("脚本名称（例如：提取 Token）", text: $script.name)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    dataModel.removeGlobalPostScript(id: script.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            CustomTextEditor(text: $script.command)
                                .frame(minHeight: 90)
                                .padding(6)
                                .background(NetworkTheme.panelBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(NetworkTheme.panelBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(10)
                        .background(NetworkTheme.panelBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(NetworkTheme.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(12)
        .background(NetworkTheme.sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(NetworkTheme.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var preScriptSelectionBinding: Binding<String?> {
        Binding(
            get: { editorStore.selectedPreScriptIDForCurrent },
            set: { editorStore.selectedPreScriptIDForCurrent = $0 }
        )
    }
    
    private func bindingForPostScriptSelection(_ scriptID: String) -> Binding<Bool> {
        Binding(
            get: {
                editorStore.selectedPostScriptIDsForCurrent.contains(scriptID)
            },
            set: { selected in
                if selected {
                    if editorStore.selectedPostScriptIDsForCurrent.contains(scriptID) == false {
                        editorStore.selectedPostScriptIDsForCurrent.append(scriptID)
                    }
                } else {
                    editorStore.selectedPostScriptIDsForCurrent.removeAll { $0 == scriptID }
                }
            }
        )
    }
    
    private func exportConfigs() {
        guard let folderURL = chooseFolder(title: "选择导出目录", prompt: "导出到此目录") else {
            AppLogger.shared.track(category: .network, name: "config_export", result: .cancelled)
            return
        }
        let operation = AppLogger.shared.begin(category: .network, name: "config_export")
        do {
            try dataModel.exportNetworkConfigs(to: folderURL)
            operation.finish(
                result: .success,
                metadata: [
                    "requestCount": String(dataModel.historyListUI.requestCount),
                    "variableCount": String(dataModel.variables.count),
                    "preScriptCount": String(dataModel.globalPreScripts.count),
                    "postScriptCount": String(dataModel.globalPostScripts.count)
                ]
            )
            showAlert(msg: "导出成功：\(dataModel.exportFileNamesDescription())")
        } catch {
            operation.finish(result: .failure, metadata: ["stage": "write_files"])
            showAlert(msg: "导出失败：\(error.localizedDescription)")
        }
    }
    
    private func importConfigs() {
        guard let folderURL = chooseFolder(title: "选择导入目录", prompt: "从此目录导入") else {
            AppLogger.shared.track(category: .network, name: "config_import", result: .cancelled)
            return
        }
        let operation = AppLogger.shared.begin(category: .network, name: "config_import")
        do {
            try dataModel.importNetworkConfigs(from: folderURL)
            operation.finish(
                result: .success,
                metadata: [
                    "requestCount": String(dataModel.historyListUI.requestCount),
                    "variableCount": String(dataModel.variables.count),
                    "preScriptCount": String(dataModel.globalPreScripts.count),
                    "postScriptCount": String(dataModel.globalPostScripts.count)
                ]
            )
            showAlert(msg: "导入成功，已更新历史记录、变量和全局脚本（含前置/后置）")
        } catch {
            operation.finish(result: .failure, metadata: ["stage": "read_files"])
            showAlert(msg: "导入失败：\(error.localizedDescription)")
        }
    }
    
    private func chooseFolder(title: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        return panel.runModal() == .OK ? panel.url : nil
    }
}
#Preview {
    SettingsView()
}
