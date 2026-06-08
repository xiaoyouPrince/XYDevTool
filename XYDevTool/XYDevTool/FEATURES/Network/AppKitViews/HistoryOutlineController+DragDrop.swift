//
//  HistoryOutlineController+DragDrop.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import AppKit

extension HistoryOutlineController {
    
    func configureDragAndDrop(on outlineView: NSOutlineView) {
        outlineView.registerForDraggedTypes([HistoryDragDrop.pasteboardType])
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        if #available(macOS 11.0, *) {
            outlineView.draggingDestinationFeedbackStyle = .gap
        }
    }
    
    func updateDropTargetHighlight(groupId: String?) {
        guard let outlineView else { return }
        let previous = dropTargetGroupId
        dropTargetGroupId = groupId
        
        for id in Set([previous, groupId].compactMap({ $0 })) {
            guard let row = rowIndex(forNodeId: id, in: roots),
                  let rowView = outlineView.rowView(atRow: row, makeIfNecessary: false) as? HistoryTableRowView else {
                continue
            }
            rowView.isDropTarget = (id == groupId)
        }
    }
    
    func parentId(forProposedItem item: Any?) -> String? {
        (item as? HistoryNode)?.id
    }
    
    func isValidMove(draggedId: String, toParentId: String?) -> Bool {
        if draggedId == toParentId { return false }
        if let toParentId, HistoryTree.isDescendant(nodeId: toParentId, of: draggedId, in: actions.historyRoots()) {
            return false
        }
        return true
    }
    
    func performDrop(draggedId: String, parentId: String?, insertIndex: Int) {
        let roots = actions.historyRoots()
        guard let draggedLocation = HistoryTree.findNode(id: draggedId, in: roots) else { return }
        
        var siblings = HistoryTree.children(of: parentId, in: roots)
        guard let fromIndex = siblings.firstIndex(where: { $0.id == draggedId }) else {
            actions.moveNode(id: draggedId, toParentId: parentId, atIndex: insertIndex)
            return
        }
        
        let node = siblings.remove(at: fromIndex)
        var targetIndex = insertIndex
        if targetIndex > fromIndex {
            targetIndex -= 1
        }
        targetIndex = min(max(0, targetIndex), siblings.count)
        siblings.insert(node, at: targetIndex)
        let orderedIds = siblings.compactMap(\.id)
        
        if draggedLocation.parentId == parentId {
            actions.applySiblingOrder(parentId: parentId, orderedIds: orderedIds)
        } else {
            actions.moveNode(id: draggedId, toParentId: parentId, atIndex: targetIndex)
        }
    }
}
