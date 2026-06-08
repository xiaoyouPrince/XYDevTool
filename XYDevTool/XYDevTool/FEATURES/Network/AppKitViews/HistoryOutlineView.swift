//
//  HistoryOutlineView.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import AppKit

protocol HistoryOutlineContextMenuProviding: AnyObject {
    func contextMenu(for item: Any, outlineView: NSOutlineView, row: Int) -> NSMenu?
}

/// 右键菜单需子类化并重写 menu(for:)；delegate 的 outlineView(_:menuFor:) 并非系统 API。
final class HistoryOutlineView: NSOutlineView {
    
    weak var contextMenuProvider: HistoryOutlineContextMenuProviding?
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        guard row >= 0, let item = item(atRow: row) else { return nil }
        return contextMenuProvider?.contextMenu(for: item, outlineView: self, row: row)
    }
}
