//
//  HelpDocumentStore.swift
//  XYDevTool
//

import Foundation

enum HelpDocumentStore {
    
    static func content(for topic: HelpTopic) -> String {
        if let bundled = loadBundledMarkdown(named: topic.markdownFileName) {
            return bundled
        }
        return fallbackContent(for: topic)
    }
    
    private static func loadBundledMarkdown(named name: String) -> String? {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Help"),
            Bundle.main.url(forResource: name, withExtension: "md")
        ]
        for url in candidates.compactMap({ $0 }) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return nil
    }
    
    private static func fallbackContent(for topic: HelpTopic) -> String {
        switch topic {
        case .overview:
            return """
            # XYDevTool
            
            面向 macOS 的开发者工具集，集成 JSON 处理、图标生成、网络调试等常用能力。
            
            请确认 `Resource/Help` 目录下的文档已正确打包进 App。
            """
        default:
            return "# \(topic.title)\n\n文档加载失败，请检查 `Resource/Help/\(topic.markdownFileName).md` 是否已加入工程资源。"
        }
    }
    
    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
    
    static let githubURL = URL(string: "https://github.com/xiaoyouPrince/XYDevTool")!
    static let releasesURL = URL(string: "https://github.com/xiaoyouPrince/XYDevTool/releases")!
}
