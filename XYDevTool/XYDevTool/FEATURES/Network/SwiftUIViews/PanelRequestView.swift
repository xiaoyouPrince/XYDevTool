//
//  PanelRequestView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct PanelRequestView: View {
    @Environment(NetworkEditorStore.self) private var editorStore
    
    var body: some View {
        @Bindable var editor = editorStore
        
        HStack(spacing: 8) {
            VStack {
                HStack {
                    Text("请求头(仅支持JSON)")
                    Spacer()
                }
                CustomTextEditor(text: $editor.httpHeaders)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(NetworkTheme.panelBorder, width: 1)
                
            }
            .padding(8)
            .background(NetworkTheme.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack {
                HStack {
                    Text("请求参数(仅支持JSON)")
                    Spacer()
                }
                CustomTextEditor(text: $editor.httpParameters)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(NetworkTheme.panelBorder, width: 1)
            }
            .padding(8)
            .background(NetworkTheme.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    PanelRequestView()
        .environment(NetworkEditorStore())
}
