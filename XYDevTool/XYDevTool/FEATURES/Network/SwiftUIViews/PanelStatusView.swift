//
//  PanelStatusView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct PanelStatusView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    
    var body: some View {
        HStack(content: {
            Text(dataModel.status)
            Spacer()
        }).frame(height: 30)
            .padding(.horizontal)
            .background(.windowBackground)
            .border(.background)
        
    }
}

#Preview {
    PanelStatusView()
}
