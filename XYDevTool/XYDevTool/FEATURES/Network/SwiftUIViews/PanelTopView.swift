//
//  PanelTopView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct PanelTopView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    @Environment(\.colorScheme) var colorScheme
    
    enum Flavor: String, CaseIterable, Identifiable {
        case chocolate, vanilla, strawberry
        var id: Self { self }
    }
    
    @State private var selectedFlavor: Flavor = .chocolate
    
    var body: some View {
        HStack {
            Text("URL:")
            TextField("输入请求地址", text: $dataModel.urlString)
                .textFieldStyle(.roundedBorder)
            
            Picker("Method:", selection: $selectedFlavor) {
                ForEach(Flavor.allCases) { flavor in
                    Text(flavor.rawValue.capitalized)
                }
            }.frame(width: 170)
            
            Button("Submit") {
                print("action")
                dataModel.makeRequest()
            }
        }.frame(height: 60)
            .padding()
            .background(bgColor)
        
        Text(dataModel.urlString)
    }
    
    var bgColor: Color {
        if colorScheme == .dark {
            return .black
        } else {
            return .white
        }
    }
}

#Preview {
    PanelTopView()
}
