//
//  HDividerView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/8/10.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct HDividerView: View {
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
