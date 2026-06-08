//
//  PanelTopView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

enum HttpMethod: String, CaseIterable, Identifiable {
    case get, post
    var id: Self { self }
}

struct PanelTopView: View {
    let onSubmit: () -> Void
    @Environment(NetworkEditorStore.self) private var editorStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        @Bindable var editor = editorStore
        
        VStack {
            HStack {
                Text("Name:")
                TextField("输入请求名称, 后续作为请求标记(默认使用 url 地址)", text: $editor.requesName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(NetworkTheme.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.trailing, 25)
                
                Toggle("🔒", isOn: $editor.isLock)
            }
            
            HStack {
                Text("URL:")
                TextField("输入请求地址", text: $editor.urlString)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(NetworkTheme.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Picker("Method:", selection: $editor.httpMethod) {
                    ForEach(HttpMethod.allCases) { method in
                        Text(method.rawValue.uppercased())
                            .tag(method)
                    }
                }.frame(width: 170)
                
                Button("Submit", action: onSubmit)
            }
        }.frame(height: 60)
            .padding()
            .background(bgColor)
            .overlay(
                Rectangle()
                    .fill(NetworkTheme.panelBorder)
                    .frame(height: 1),
                alignment: .bottom
            )
    }
    
    var bgColor: Color {
        if colorScheme == .dark {
            return .cyan.opacity(0.25)
        } else {
            return .blue.opacity(0.25)
        }
    }
}

#Preview {
    let model = NetworkDataModel()
    PanelTopView(onSubmit: {})
        .environment(model.editor)
}
