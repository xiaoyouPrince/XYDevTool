//
//  PanelTopView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

enum HttpMethod: String, CaseIterable, Identifiable {
    case get, post
    var id: Self { self }
}

struct PanelTopView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            HStack {
                Text("Name:")
                TextField("输入请求名称, 后续作为请求标记(默认使用 url 地址)", text: $dataModel.requesName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.trailing, 25)
                
                Toggle("🔒", isOn: $dataModel.isLock)
            }
            
            HStack {
                Text("URL:")
                TextField("输入请求地址", text: $dataModel.urlString)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Method:", selection: $dataModel.httpMethod) {
                    ForEach(HttpMethod.allCases) { method in
                        Text(method.rawValue.uppercased())
                            .tag(method)
                    }
                }.frame(width: 170)
                
                Button("Submit") {
                    print("action")
                    dataModel.makeRequest()
                }
            }
        }.frame(height: 60)
            .padding()
            .background(bgColor)
    }
    
    var bgColor: Color {
        if colorScheme == .dark {
            return .cyan.opacity(0.25)
        } else {
            return .blue.opacity(0.25)
        }
    }
}

#Preview {
    PanelTopView()
}
