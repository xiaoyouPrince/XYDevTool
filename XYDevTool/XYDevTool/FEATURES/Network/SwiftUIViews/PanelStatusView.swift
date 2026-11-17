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
        PanelStatusBar(dataModel: dataModel, mock: dataModel.mockController)
    }
}

private struct PanelStatusBar: View {
    @ObservedObject var dataModel: NetworkDataModel
    @ObservedObject var mock: NetworkMockController
    
    var body: some View {
        HStack {
            Text(dataModel.status)
            Spacer()
            if mock.isRunning {
                Text("Mock :\(mock.portText)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Button {
                dataModel.auxiliaryWindows.showAPIDoc()
            } label: {
                Label("文档", systemImage: "doc.text")
            }
            Button {
                dataModel.auxiliaryWindows.showMock()
            } label: {
                Label("Mock", systemImage: "server.rack")
            }
            Button {
                dataModel.auxiliaryWindows.showSettings()
            } label: {
                Image(systemName: "gear.circle.fill")
            }
        }
        .frame(height: 30)
        .padding(.horizontal)
        .background(NetworkTheme.panelBackground)
        .border(NetworkTheme.panelBorder)
    }
}

#Preview {
    PanelStatusView()
}
