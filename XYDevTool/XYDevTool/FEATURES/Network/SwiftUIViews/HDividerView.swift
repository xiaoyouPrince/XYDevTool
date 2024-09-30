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
            .fill(Color.gray.opacity(0.3))
            .frame(width: dividerWidth)
            .clipShape(RoundedRectangle(cornerSize: .init(width: dividerWidth, height: dividerWidth), style: .circular))
            .onAppear {
                self.lastLocation = CGPoint(x: self.leftWidth + self.dividerWidth / 2, y: 0)
            }
            .transaction { transaction in
                transaction.animation = nil // 禁用动画
            }
            .overlay {
                ZStack {
//                    Image(systemName: "ellipsis")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: dividerWidth / 3 * 2)
//                        .disabled(true)
                    VStack(spacing: 7) {
                        ZStack {
                            Color.white.frame(width: dividerWidth / 3 * 2, height: dividerWidth / 3 * 2)
                                .clipShape(RoundedRectangle(cornerRadius: dividerWidth/3))
                        }
                        ZStack {
                            Color.white.frame(width: dividerWidth / 3 * 2, height: dividerWidth / 3 * 2)
                                .clipShape(RoundedRectangle(cornerRadius: dividerWidth/3))
                        }
                        ZStack {
                            Color.white.frame(width: dividerWidth / 3 * 2, height: dividerWidth / 3 * 2)
                                .clipShape(RoundedRectangle(cornerRadius: dividerWidth/3))
                        }
                    }
                }
                .rotationEffect(Angle(degrees: .pi/4))
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newWidth = self.leftWidth + value.translation.width
                        if newWidth >= 0 && newWidth <= self.totalWidth - self.dividerWidth {
                            self.leftWidth = newWidth
                        }
                    }
            )
    }
}
