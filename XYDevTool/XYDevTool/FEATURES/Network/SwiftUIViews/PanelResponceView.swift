//
//  PanelResponceView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct PanelResponceView: View {
    @Environment(NetworkEditorStore.self) private var editorStore
    
    var body: some View {
        @Bindable var editor = editorStore
        
        ZStack {
            HStack {
                VStack {
                    HStack {
                        Text("请求结果")
                        Spacer()
                    }
                    CustomTextEditor(text: $editor.httpResponse)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(NetworkTheme.panelBorder, width: 1)
                }
                .padding(8)
                .background(NetworkTheme.sectionBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

#Preview {
    PanelResponceView()
        .environment(NetworkEditorStore())
}
