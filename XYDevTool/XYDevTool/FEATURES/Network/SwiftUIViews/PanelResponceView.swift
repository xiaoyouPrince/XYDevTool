//
//  PanelResponceView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct PanelResponceView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    
    var body: some View {
        ZStack {
            HStack {
                VStack {
                    HStack {
                        Text("请求结果")
                        Spacer()
                    }
                    CustomTextEditor(text: $dataModel.httpResponse)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(.background, width: 1)
                }
            }
        }
    }
}

#Preview {
    PanelResponceView()
}
