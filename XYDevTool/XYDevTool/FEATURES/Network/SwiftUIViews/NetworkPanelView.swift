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
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                PanelTopView()
                HStack {
                    PanelHistoryView()
                        .frame(width: leftWidth)
                    
                    // 可拖拽的分隔线
                    //DividerView(leftWidth: $leftWidth, dividerWidth: $dividerWidth)
                    DividerView(leftWidth: self.$leftWidth, dividerWidth: self.$dividerWidth, totalWidth: geometry.size.width)
                    
                    VStack {
                        PanelRequestView()
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

struct DividerView: View {
    @Binding var leftWidth: CGFloat
    @Binding var dividerWidth: CGFloat
    var totalWidth: CGFloat
    @State private var lastLocation: CGPoint = .zero
    
    var body: some View {
        Rectangle()
            .fill(Color.gray)
            .frame(width: dividerWidth)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newWidth = self.leftWidth + value.translation.width
                        if newWidth >= 0 && newWidth <= self.totalWidth - self.dividerWidth {
                            self.leftWidth = newWidth
                        }
                    }
            )
            .onAppear {
                self.lastLocation = CGPoint(x: self.leftWidth + self.dividerWidth / 2, y: 0)
            }
            .transaction { transaction in
                transaction.animation = nil // 禁用动画
            }
    }
}

