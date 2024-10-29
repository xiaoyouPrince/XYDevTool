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

/*
struct JSONFormatterView: View {
    @State private var codeText = """
    // 在此处编写代码
    function greet() {
        console.log("Hello, CodeMirror!");
    }
    greet();
    """
    
    var body: some View {
        VStack {
            Text("CodeMirror Editor in macOS App")
                .font(.title)
                .padding()
            
            WebView(codeText: $codeText) // 绑定初始代码文本
                .frame(minWidth: 800, minHeight: 600)
            
            Button("Update Code") {
                codeText = """
                // 更新后的代码
                function newGreet() {
                    console.log("Updated Code in CodeMirror!");
                }
                newGreet();
                """
            }
            .padding()
        }
    }
}
*/


struct JSONFormatterView: View {
    @State var text: String = ""
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            HStack {
                WebView(codeText: $text) // 使用 WebView 组件加载 Apple 官网
                    .frame(minWidth: 600, minHeight: 400) // 设置 WebView 的大小
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(.background, width: 1)
                    .padding(.vertical)
                    .padding(.leading)
                    .colorScheme(.light)
                
                JSONFormatterFunctionsView(text: $text)
                    .padding(.trailing)
            }
        }
    }
}

import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    @Binding var codeText: String
    private var isUpdatingFromEditor = false // 标志位：检测是否来自编辑器的更新
    
    init(codeText: Binding<String>) {
        _codeText = codeText
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.configuration.userContentController.add(context.coordinator, name: "editorContentDidChange")
        loadLocalHTML(webView)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 只有当 codeText 不是来自 editor 的更新时，才设置 editor 内容
        if !isUpdatingFromEditor {
            setCodeText(nsView)
        }
    }
    
    private func loadLocalHTML(_ webView: WKWebView) {
        if let filePath = Bundle.main.path(forResource: "index", ofType: "html") {
            let fileURL = URL(fileURLWithPath: filePath)
            let directoryURL = fileURL.deletingLastPathComponent()
            webView.loadFileURL(fileURL, allowingReadAccessTo: directoryURL)
        }
    }
    
    private func setCodeText(_ webView: WKWebView) {
        let sanitizedText = codeText.debugDescription
        let javascript = """
        (function checkEditor() {
            if (typeof editor !== 'undefined' && editor.getValue() !== \(sanitizedText)) {
                editor.setValue(\(sanitizedText));
            } else if (typeof editor === 'undefined') {
                setTimeout(checkEditor, 100);
            }
        })();
        """
        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                print("Error executing JavaScript: \(error)")
            } else {
                print("JavaScript executed successfully")
            }
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.setCodeText(webView)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "editorContentDidChange", let code = message.body as? String {
                DispatchQueue.main.async {
                    self.parent.isUpdatingFromEditor = true
                    self.parent.codeText = code
                    self.parent.isUpdatingFromEditor = false
                }
            }
        }
    }
}
