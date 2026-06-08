//
//  HistoryOutlineRepresentable.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI
import AppKit

/// 将 AppKit 历史树嵌入 SwiftUI 左栏。
struct HistoryOutlineRepresentable: NSViewRepresentable {
    let actions: HistoryListActions
    let listUI: HistoryListUIStore
    
    func makeCoordinator() -> HistoryOutlineController {
        HistoryOutlineController(actions: actions)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor
        scrollView.borderType = .noBorder
        
        let outlineView = HistoryOutlineView()
        outlineView.contextMenuProvider = context.coordinator
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .small
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.backgroundColor = .controlBackgroundColor
        outlineView.selectionHighlightStyle = .none
        if #available(macOS 11.0, *) {
            outlineView.style = .sourceList
        }
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("HistoryColumn"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        scrollView.documentView = outlineView
        context.coordinator.attach(outlineView: outlineView)
        
        let roots = actions.historyRoots()
        context.coordinator.treeRevision = listUI.treeRevision
        context.coordinator.selectedId = listUI.selectedId
        context.coordinator.reload(roots: roots, selectedId: listUI.selectedId)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        
        if let outlineView = scrollView.documentView as? HistoryOutlineView {
            outlineView.contextMenuProvider = coordinator
        }
        
        if coordinator.treeRevision != listUI.treeRevision {
            coordinator.treeRevision = listUI.treeRevision
            coordinator.reload(roots: actions.historyRoots(), selectedId: listUI.selectedId)
        }
        
        if coordinator.selectedId != listUI.selectedId {
            coordinator.syncSelection(to: listUI.selectedId)
        }
    }
}
