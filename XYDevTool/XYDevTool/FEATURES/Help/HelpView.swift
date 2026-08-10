//
//  HelpView.swift
//  XYDevTool
//

import SwiftUI

final class HelpPresentationState: ObservableObject {
    @Published var selectedTopic: HelpTopic = .overview
}

struct HelpView: View {
    @ObservedObject var state: HelpPresentationState
    
    var body: some View {
        NavigationSplitView {
            List(selection: $state.selectedTopic) {
                Section("总览") {
                    topicRow(.overview)
                    topicRow(.gettingStarted)
                }
                Section("功能模块") {
                    topicRow(.jsonFormatter)
                    topicRow(.json2Model)
                    topicRow(.appIcon)
                    topicRow(.networkTool)
                    topicRow(.customServer)
                    topicRow(.imageInspector)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            HelpMarkdownView(
                title: state.selectedTopic.title,
                content: HelpDocumentStore.content(for: state.selectedTopic)
            )
        }
        .frame(minWidth: 820, minHeight: 560)
    }
    
    private func topicRow(_ topic: HelpTopic) -> some View {
        Text(topic.title)
            .tag(topic)
    }
}

private struct HelpMarkdownView: View {
    let title: String
    let content: String
    
    private var html: String {
        HelpMarkdownRenderer.htmlDocument(body: content, title: title)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("版本 \(HelpDocumentStore.appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            Divider()
            
            HelpWebView(html: html)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading)
                .padding(.trailing, 8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
