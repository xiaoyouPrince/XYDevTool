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
            Text("请求完成后脚本（可更新变量）")
                .font(.title3)
                .fontWeight(.semibold)
            Text("此输入框为完整命令模板，支持直接写 $1/$2（示例：swift /Users/quxiaoyou/Desktop/Shell/swift2.swift \"$1\" \"$2\"）。\n其中：$1=响应文本，$2=当前变量JSON。\n脚本输出支持 3 种格式：\n1) JSON 包裹变量：{\"variables\":{\"token\":\"xxx\"}}\n2) 直接 JSON 对象：{\"token\":\"xxx\",\"uid\":\"1001\"}\n3) 多行 key=value：token=xxx\\nuid=1001\n注意：key 不能为空；重复 key 以最后一条为准。")
                .font(.caption)
                .foregroundStyle(.secondary)
            CustomTextEditor(text: $dataModel.postResponseScript)
                .frame(minHeight: 140)
                .padding(6)
                .background(NetworkTheme.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(NetworkTheme.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
        .background(NetworkTheme.sectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(NetworkTheme.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
#Preview {
    SettingsView()
}
