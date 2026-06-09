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
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = .clear
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawBackground(inClipRect clipRect: NSRect) {
        // 不绘制底色，由 SwiftUI 父视图统一铺色。
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        guard row >= 0, let item = item(atRow: row) else { return nil }
        return contextMenuProvider?.contextMenu(for: item, outlineView: self, row: row)
    }
}
