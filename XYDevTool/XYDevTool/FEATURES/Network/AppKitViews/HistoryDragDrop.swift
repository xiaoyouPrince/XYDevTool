//
//  HistoryDragDrop.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import AppKit

enum HistoryDragDrop {
    static let pasteboardType = NSPasteboard.PasteboardType("com.xiaoyou.xydevtool.history-node-id")
    
    static func nodeId(from info: NSDraggingInfo) -> String? {
        info.draggingPasteboard.string(forType: pasteboardType)
    }
}
