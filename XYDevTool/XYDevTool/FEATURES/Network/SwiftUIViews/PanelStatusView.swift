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
    
    @State var showSettings: Bool = false
    
    var body: some View {
        HStack(content: {
            Text(dataModel.status)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear.circle.fill")
            }

        }).frame(height: 30)
            .padding(.horizontal)
            .background(Color(nsColor: .windowBackgroundColor))
            .border(.background)
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .frame(minWidth: 400, minHeight: 300)
            }
            
        
    }
}

#Preview {
    PanelStatusView()
}
