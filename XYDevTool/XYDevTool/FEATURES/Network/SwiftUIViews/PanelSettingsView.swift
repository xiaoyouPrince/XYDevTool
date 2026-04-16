//
//  PanelSettingsView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/9/27.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    variableSection
                    globalScriptSection
                    scriptSection
                }
                .padding()
            }
            
            if dataModel.variables.isEmpty {
                EmptyView()
            }
            
            HStack {
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
    
    private var scriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前接口脚本选择")
                .font(.title3)
                .fontWeight(.semibold)
            Text("从全局脚本库中勾选当前接口要执行的脚本（可多选）。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if dataModel.currentHistory == nil {
                Text("未选中历史请求，无法绑定脚本。请先在左侧选择一个请求。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else if dataModel.globalPostScripts.isEmpty {
                Text("暂无全局脚本，请先在上方“全局后置脚本库”新增。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(dataModel.globalPostScripts) { script in
                        Toggle(isOn: bindingForScriptSelection(script.id.uuidString)) {
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
    
    private func bindingForScriptSelection(_ scriptID: String) -> Binding<Bool> {
        Binding(
            get: {
                dataModel.selectedPostScriptIDsForCurrent.contains(scriptID)
            },
            set: { selected in
                if selected {
                    if dataModel.selectedPostScriptIDsForCurrent.contains(scriptID) == false {
                        dataModel.selectedPostScriptIDsForCurrent.append(scriptID)
                    }
                } else {
                    dataModel.selectedPostScriptIDsForCurrent.removeAll { $0 == scriptID }
                }
            }
        )
    }
}
#Preview {
    SettingsView()
}
