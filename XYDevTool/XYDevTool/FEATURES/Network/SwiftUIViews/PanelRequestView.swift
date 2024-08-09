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



import AppKit

struct CustomTextEditor: NSViewRepresentable {
    
    @Environment(\.colorScheme) var colorScheme
    @Binding var text: String
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            DispatchQueue.main.async {
                self.parent.text = textView.string
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.delegate = context.coordinator
        
        if colorScheme == .dark {
            textView.backgroundColor = .windowBackgroundColor
        } else {
            textView.backgroundColor = .windowBackgroundColor
        }
        
        textView.font = NSFont.systemFont(ofSize: 16)
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        
        // 关闭自动调整大小
        scrollView.autoresizingMask = [.width, .height]
        textView.autoresizingMask = [.width, .height]
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != self.text {
                textView.string = self.text
            }
        }
    }
}
