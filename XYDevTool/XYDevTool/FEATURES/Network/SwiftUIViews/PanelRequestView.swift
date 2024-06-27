//
//  PanelRequestView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct PanelRequestView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    
    var body: some View {
        ZStack {
            Color.red
            HStack {
                VStack {
                    Text("请求头(仅支持JSON)")
                    TextEditor(text: $dataModel.httpHeaders)
                }
                
                VStack {
                    Text("请求参数(仅支持JSON)")
                    TextEditor(text: $dataModel.httpParameters)
                }
            }
        }
    }
}

#Preview {
    PanelRequestView()
}
