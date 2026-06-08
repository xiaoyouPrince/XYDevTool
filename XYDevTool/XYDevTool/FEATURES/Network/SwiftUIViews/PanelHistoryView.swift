//
//  PanelHistoryView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

/// 历史列表容器：顶栏 SwiftUI + 树列表 AppKit（Phase 1）。
struct PanelHistoryView: View {
    @Environment(HistoryListUIStore.self) private var listUI
    let actions: HistoryListActions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("请求历史(\(listUI.requestCount))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: { actions.createGroup() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("新建分组（选中分组时在其下创建，否则在根级创建）")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            HistoryOutlineRepresentable(actions: actions, listUI: listUI)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(NetworkTheme.sectionBackground)
    }
}

#Preview {
    let model = NetworkDataModel()
    PanelHistoryView(actions: model.historyActions)
        .environment(model.historyListUI)
        .environment(model.editor)
        .frame(width: 260, height: 400)
}
