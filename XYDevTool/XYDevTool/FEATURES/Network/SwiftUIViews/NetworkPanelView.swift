//
//  NetworkPanelView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct NetworkPanelView: View {
    @State private var leftWidth: CGFloat = 250 // 初始左侧视图宽度
    @State private var dividerWidth: CGFloat = 10 // 分隔线宽度
    
    @State private var topHeight: CGFloat = 200 // 初始上侧视图高度
    @State private var dividerHeight: CGFloat = 10 // 分隔线高度
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                PanelTopView()
                HStack {
                    PanelHistoryView()
                        .frame(width: leftWidth)
                    
                    // 可拖拽的分隔线
                    HDividerView(leftWidth: self.$leftWidth, dividerWidth: self.$dividerWidth, totalWidth: geometry.size.width)
                    
                    VStack {
                        PanelRequestView()
                            .frame(height: min(max(self.topHeight, 50), 200))
                        
                        // 可拖拽的分隔线
                        VDividerView(topHeight: self.$topHeight, dividerHeight: self.$dividerHeight, totalHeight: geometry.size.height)
                        
                        PanelResponceView()
                    }.padding(.trailing, 8)
                }
                PanelStatusView()
            }
            .frame(minWidth: 350, idealWidth: 700, maxWidth: .infinity,
                   minHeight: 200, idealHeight: 450, maxHeight: .infinity)
        }
    }
}

#Preview {
    NetworkPanelView()
}

