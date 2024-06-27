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
                    let item = dataModel.historyArray[idx]
                    let hisName = item.name ?? ""
                    let isLock = item.isLock ?? false
                    ZStack {
                        self.selectedItem == hisName ? Color.blue.opacity(0.5) : Color.blue.opacity(0.1)
                        HStack {
                            Text(hisName)
                                .font(.body)
                            Spacer()
                            Text("delete")
                                .onTapGesture {
                                    if isLock {
                                        showAlert(msg: "您要移除的记录为【" + hisName + "】它是锁定的记录，不能直接删除，需要先接触锁定")
                                    } else {
                                        let itemIndex = dataModel.historyArray.firstIndex(where: {$0.name == hisName})!
                                        dataModel.historyArray.remove(at: itemIndex)
                                    }
                                }
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
