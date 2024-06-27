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
            Color.blue
            HStack {
                VStack {
                    Text("请求结果")
                    TextEditor(text: $dataModel.httpResponse)
                }
            }
        }
    }
}

#Preview {
    PanelResponceView()
}
