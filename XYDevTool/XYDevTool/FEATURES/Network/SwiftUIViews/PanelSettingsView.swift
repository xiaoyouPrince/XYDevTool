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
        VStack(spacing: 12) {
            HStack {
                Text("变量设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("新增变量") {
                    dataModel.addVariable()
                }
            }
            
            if dataModel.variables.isEmpty {
                Spacer()
                Text("暂无变量，点击右上角“新增变量”开始配置")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
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
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
            
            HStack {
                Spacer()
                Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
#Preview {
    SettingsView()
}
