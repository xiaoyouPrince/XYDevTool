//
//  JSONFormatterView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/9/30.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI
import Combine
import WebKit

struct JSONFormatterView: View {
    @State var text: String = ""
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            HStack {
                WebView()//urlString: "https://www.apple.com") // 使用 WebView 组件加载 Apple 官网
//                    .frame(minWidth: 600, minHeight: 400) // 设置 WebView 的大小
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .border(.background, width: 1)
//                    .padding(.vertical)
//                    .padding(.leading)
//                    .colorScheme(.light)
                
                JSONFormatterFunctionsView(text: $text)
                    .padding(.trailing)
            }
        }
    }
}


//// Step 1: 创建 WebView 结构体，实现 NSViewRepresentable
//struct WebView: NSViewRepresentable {
//    let urlString: String // 要加载的 URL
//    
//    // 创建 WKWebView 实例
//    func makeNSView(context: Context) -> WKWebView {
//        return WKWebView()
//    }
//    
//    // 更新 WKWebView 的内容
//    func updateNSView(_ nsView: WKWebView, context: Context) {
//        if let url = URL(string: urlString) {
//            let request = URLRequest(url: url)
//            nsView.load(request) // 加载指定 URL
//        }
//    }
//}

// Step 1: 创建 WebView 结构体，实现 NSViewRepresentable
struct WebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        loadLocalHTML(webView)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 在这里可以处理视图更新
    }
    
    // 加载本地 HTML 文件
    private func loadLocalHTML(_ webView: WKWebView) {
        if let filePath = Bundle.main.path(forResource: "index", ofType: "html") {
            let fileURL = URL(fileURLWithPath: filePath)
            let directoryURL = fileURL.deletingLastPathComponent()
            webView.loadFileURL(fileURL, allowingReadAccessTo: directoryURL)
        }
    }
}

