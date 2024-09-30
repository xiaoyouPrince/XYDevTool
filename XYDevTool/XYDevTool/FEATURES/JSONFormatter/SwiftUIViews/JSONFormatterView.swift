//
//  JSONFormatterView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/9/30.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct JSONFormatterView: View {
    @State var text: String = ""
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            HStack {
                CustomTextEditor(text: $text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(.background, width: 1)
                    .padding()
                    .colorScheme(.light)
                
                JSONFormatterFunctionsView(text: $text)
                    .padding(.trailing)
            }
        }
    }
}

#Preview {
    JSONFormatterView()
}
