//
//  NetworkPanelView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

/// 网络窗口根视图：不订阅 NetworkDataModel，避免编辑区刷新连带重绘历史列表。
struct NetworkHostingRoot: View {
    let dataModel: NetworkDataModel
    
    var body: some View {
        NetworkPanelView(actions: dataModel.historyActions)
            .environmentObject(dataModel)
            .environment(dataModel.historyListUI)
            .environment(dataModel.editor)
    }
}

struct NetworkPanelView: View {
    let actions: HistoryListActions
    
    @State private var leftWidth: CGFloat = 250
    @State private var dividerWidth: CGFloat = 10
    @State private var topHeight: CGFloat = 200
    @State private var dividerHeight: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                PanelTopView(onSubmit: actions.makeRequest)
                HStack {
                    PanelHistoryView(actions: actions)
                        .frame(width: leftWidth)
                    
                    HDividerView(leftWidth: self.$leftWidth, dividerWidth: self.$dividerWidth, totalWidth: geometry.size.width)
                    
                    VStack {
                        PanelRequestView()
                            .frame(height: min(max(self.topHeight, 50), 200))
                        
                        VDividerView(topHeight: self.$topHeight, dividerHeight: self.$dividerHeight, totalHeight: geometry.size.height)
                        
                        PanelResponceView()
                    }.padding(.trailing, 8)
                }
                PanelStatusView()
            }
            .frame(minWidth: 350, idealWidth: 700, maxWidth: .infinity,
                   minHeight: 200, idealHeight: 450, maxHeight: .infinity)
            .background(NetworkTheme.panelBackground)
        }
    }
}

#Preview {
    let model = NetworkDataModel()
    NetworkHostingRoot(dataModel: model)
}
