//
//  PanelAPIDocView.swift
//  XYDevTool
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PanelAPIDocView: View {
    @EnvironmentObject private var dataModel: NetworkDataModel
    
    private enum PreviewMode: String, CaseIterable, Identifiable {
        case rendered = "文档预览"
        case source = "Markdown 源码"
        
        var id: String { rawValue }
    }
    
    @State private var markdown: String = ""
    @State private var statusMessage: String?
    @State private var useSelectedGroupOnly = false
    @State private var previewMode: PreviewMode = .rendered
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("接口文档")
                    .font(.title2.bold())
                Spacer()
                Button("重新生成") {
                    regenerate()
                }
                Button("复制") {
                    copyMarkdown()
                }
                .disabled(markdown.isEmpty)
                Button("导出…") {
                    exportMarkdown()
                }
                .disabled(markdown.isEmpty)
            }
            
            HStack(spacing: 16) {
                Toggle("仅当前选中分组", isOn: $useSelectedGroupOnly)
                    .toggleStyle(.checkbox)
                    .disabled(selectedGroup == nil)
                    .help("需在左侧历史中选中一个分组后可用")
                
                if let selectedGroup {
                    Text("当前分组：\(selectedGroup.name ?? "未命名")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("未选中分组时将导出全部历史")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            Text("版式对齐后台手写说明：标题 / uri / Method / 带类型注释的请求与响应 JSON；枚举与错误码需人工补充。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Picker("", selection: $previewMode) {
                ForEach(PreviewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Group {
                switch previewMode {
                case .rendered:
                    HelpWebView(html: renderedHTML)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                case .source:
                    TextEditor(text: $markdown)
                        .font(.system(.body, design: .monospaced))
                        .border(Color.secondary.opacity(0.25))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            regenerate()
        }
        .onChange(of: useSelectedGroupOnly) { _ in
            regenerate()
        }
    }
    
    private var renderedHTML: String {
        HelpMarkdownRenderer.htmlDocument(body: markdown, title: "接口文档")
    }
    
    private var selectedGroup: HistoryNode? {
        guard let id = dataModel.historyListUI.selectedId,
              let node = HistoryTree.findNode(id: id, in: dataModel.historyRoots)?.node,
              node.isGroup else {
            return nil
        }
        return node
    }
    
    private func currentScope() -> APIDocScope {
        if useSelectedGroupOnly, let group = selectedGroup, let id = group.id {
            return .group(id: id, name: group.name ?? "未命名分组")
        }
        return .all
    }
    
    private func regenerate() {
        if useSelectedGroupOnly && selectedGroup == nil {
            useSelectedGroupOnly = false
        }
        markdown = APIDocMarkdownGenerator.generate(
            from: dataModel.historyRoots,
            scope: currentScope()
        )
        let chapterCount = markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.hasPrefix("uri:") }
            .count
        statusMessage = "已生成 \(chapterCount) 个接口（预览为渲染文档，可切换 Markdown 源码）"
        previewMode = .rendered
    }
    
    private func copyMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        statusMessage = "已复制 Markdown 源码到剪贴板"
    }
    
    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.title = "导出接口文档"
        panel.nameFieldStringValue = "api-docs.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        let target = url.pathExtension.isEmpty ? url.appendingPathExtension("md") : url
        do {
            try markdown.write(to: target, atomically: true, encoding: .utf8)
            statusMessage = "已导出到 \(target.lastPathComponent)"
        } catch {
            statusMessage = "导出失败：\(error.localizedDescription)"
        }
    }
}
