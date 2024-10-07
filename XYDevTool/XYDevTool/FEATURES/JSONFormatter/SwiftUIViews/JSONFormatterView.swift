//
//  JSONFormatterView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/9/30.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI
import Combine


struct JSONFormatterView: View {
    @State var text: String = ""
    @State var document = CodeEditorDemoDocument()
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            HStack {
                //lineNumberView(text: $text)
                
                CustomTextEditor(text: $text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(.background, width: 1)
                    .padding(.vertical)
                    .padding(.leading)
                    .colorScheme(.light)
                
//                ContentView(document: $document)
                
                
                
                JSONFormatterFunctionsView(text: $text)
                    .padding(.trailing)
            }
        }
    }
}

//#Preview {
//    JSONFormatterView()
//}


struct lineNumberView: View {
    @Binding var text: String
//    @State var lineNumber: Int = 0
    static var tv: NSTextView?
    
    var body: some View {
        let lineNumber = getLineNumbers()
        VStack(alignment: .leading) {
            ForEach(lineNumber.indices, id: \.self) { idx in
                Text(lineNumber[idx])
                    .id(idx)
            }
            Spacer()
        }
        .padding(.top)
    }
    
    func getLineNumbers() -> [String] {
        let lineCount = text.components(separatedBy: "\n").count
        let lineNumbers = (1...lineCount).map { "\($0)" }
        return lineNumbers
    }
}
