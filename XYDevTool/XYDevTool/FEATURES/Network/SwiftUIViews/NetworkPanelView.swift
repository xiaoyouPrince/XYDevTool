//
//  NetworkPanelView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct NetworkPanelView: View {
    var body: some View {
        VStack {
            PanelTopView()
            Spacer()
            HStack {
                PanelHistoryView()
                VStack {
                    PanelRequestView()
                    PanelResponceView()
                }
            }
            PanelStatusView()
        }
            .frame(minWidth: 350, idealWidth: 700, maxWidth: NSScreen.main?.frame.size.width,
            minHeight: 200, idealHeight: 450, maxHeight: NSScreen.main?.frame.size.height)
            
    }
}

#Preview {
    NetworkPanelView()
}
