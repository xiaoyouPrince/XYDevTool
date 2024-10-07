//
//  CustomTextEditor.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/8/9.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI
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
        
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        
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
