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
    
    @State private var selectedItem: String? = nil
    
    var body: some View {
        List {
            Section {
                ForEach(dataModel.historyArray.indices, id: \.self) { idx in
                    
                    let hisName = dataModel.historyArray[idx].name ?? ""
                    ZStack {
                        self.selectedItem == hisName ? Color.blue.opacity(0.5) : Color.blue.opacity(0.1)
                        HStack {
                            Text(hisName)
                                .font(.body)
                            Spacer()
                        }
                    }.onTapGesture {
                        selectedItem = hisName
                        dataModel.setCurrentHistory(with: hisName)
                        print(hisName)
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
