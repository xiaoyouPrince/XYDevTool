//
//  PanelHistoryView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct PanelHistoryView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    
    var body: some View {
        List {
            Section {
                ForEach(dataModel.historyArray.indices, id: \.self) { idx in
                    Text("\(dataModel.historyArray[idx].name ?? "")")
                        .onTapGesture {
                            print(dataModel.historyArray[idx].name ?? "")
                        }
                }
            } header: {
                HStack {
                    Text("请求历史(\(dataModel.historyArray.count))")
                }
            }
        }
        
    }
}

#Preview {
    PanelHistoryView()
}
