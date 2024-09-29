//
//  PanelSettingsView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/9/27.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

// 设置页面
struct SettingsView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    @Environment(\.presentationMode) var presentationMode // 用于关闭设置页面
    @State private var settingOption = false              // 一个简单的设置选项示例
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()
            
            // 简单的设置选项
            Toggle(isOn: $settingOption) {
                Text("Enable Option")
            }
            .padding()
            
            CustomTextEditor(text: $dataModel.userScript)
                .frame(width: .infinity, height: .infinity)
            
            Spacer()
            
            // 完成设置按钮，关闭视图
            Button("Save and Close") {
                // 可以在这里保存设置，然后关闭页面
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 设置页面占满窗口
        .padding()
    }
}
#Preview {
    SettingsView()
}
