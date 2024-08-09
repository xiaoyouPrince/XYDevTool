//
//  VDividerView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/8/10.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct VDividerView: View {
    @Binding var topHeight: CGFloat
    @Binding var dividerHeight: CGFloat
    var totalHeight: CGFloat
    @State private var lastLocation: CGPoint = .zero
    
    var body: some View {
        Rectangle()
            .fill(Color.gray)
            .frame(height: dividerHeight)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newHeight = self.topHeight + value.translation.height
                        if newHeight >= 0 && newHeight <= self.totalHeight - self.dividerHeight {
                            self.topHeight = newHeight
                        }
                    }
            )
            .onAppear {
                self.lastLocation = CGPoint(x: 0, y: self.topHeight + self.dividerHeight / 2)
            }
            .transaction { transaction in
                transaction.animation = nil // 禁用动画
            }
    }
}
