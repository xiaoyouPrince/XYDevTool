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
            HStack(spacing: 8) {
                VStack {
                    HStack {
                        Text("请求头(仅支持JSON)")
                        Spacer()
                    }
                    CustomTextEditor(text: $dataModel.httpHeaders)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(.background, width: 1)
                    
                }
                
                VStack {
                    HStack {
                        Text("请求参数(仅支持JSON)")
                        Spacer()
                    }
                    CustomTextEditor(text: $dataModel.httpParameters)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .border(.background, width: 1)
                }
            }
        }
    }
}

#Preview {
    PanelRequestView()
}
