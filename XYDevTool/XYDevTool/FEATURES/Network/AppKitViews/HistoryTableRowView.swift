//
//  HistoryTableRowView.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import AppKit

/// 行背景：对齐 SwiftUI 列表的蓝底选中/悬停样式。
final class HistoryTableRowView: NSTableRowView {
    
    var isDropTarget = false {
        didSet {
            guard isDropTarget != oldValue else { return }
            needsDisplay = true
        }
    }
    
    private var isMouseInside = false
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        needsDisplay = true
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        let fillColor: NSColor
        if isDropTarget {
            fillColor = .controlAccentColor.withAlphaComponent(0.28)
        } else if isSelected {
            fillColor = .systemBlue.withAlphaComponent(0.5)
        } else if isMouseInside {
            fillColor = .systemBlue.withAlphaComponent(0.18)
        } else {
            fillColor = .systemBlue.withAlphaComponent(0.1)
        }
        fillColor.setFill()
        bounds.fill()
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        // 选中样式已在 drawBackground 中绘制。
    }
}
