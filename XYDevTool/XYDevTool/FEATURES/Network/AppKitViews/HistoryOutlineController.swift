//
//  HistoryOutlineController.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import AppKit

final class HistoryOutlineController: NSObject {
    
    weak var outlineView: NSOutlineView?
    let actions: HistoryListActions
    
    private(set) var roots: [HistoryNode] = []
    var treeRevision: Int = -1
    var selectedId: String?
    var isProgrammaticSelection = false
    var isApplyingExpansionState = false
    var draggingNodeId: String?
    var dropTargetGroupId: String?
    var renamingGroupId: String?
    
    init(actions: HistoryListActions) {
        self.actions = actions
        super.init()
    }
    
    func attach(outlineView: NSOutlineView) {
        self.outlineView = outlineView
        outlineView.dataSource = self
        outlineView.delegate = self
        configureDragAndDrop(on: outlineView)
        configureRenameAndMenu(on: outlineView)
    }
    
    func reload(roots: [HistoryNode], selectedId: String? = nil) {
        if let selectedId {
            self.selectedId = selectedId
        }
        self.roots = roots
        guard let outlineView else { return }
        
        let expandedIds = captureExpandedGroupIds()
        outlineView.reloadData()
        applyExpansionState(to: roots, preferredExpandedIds: expandedIds)
        syncSelection(to: self.selectedId)
    }
    
    func syncSelection(to id: String?) {
        guard let outlineView else { return }
        selectedId = id
        
        guard let id else {
            if outlineView.selectedRow != -1 {
                isProgrammaticSelection = true
                outlineView.deselectAll(nil)
                isProgrammaticSelection = false
            }
            return
        }
        
        guard let row = rowIndex(forNodeId: id, in: roots) else { return }
        if outlineView.selectedRow != row {
            isProgrammaticSelection = true
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
            isProgrammaticSelection = false
        }
    }
    
    // MARK: - Private
    
    func rowIndex(forNodeId id: String, in nodes: [HistoryNode]) -> Int? {
        guard let outlineView else { return nil }
        for index in 0..<outlineView.numberOfRows {
            guard let node = outlineView.item(atRow: index) as? HistoryNode, node.id == id else { continue }
            return index
        }
        return nil
    }
    
    func captureExpandedGroupIds() -> Set<String> {
        guard let outlineView else { return [] }
        var ids = Set<String>()
        for row in 0..<outlineView.numberOfRows {
            guard let node = outlineView.item(atRow: row) as? HistoryNode,
                  node.isGroup,
                  let id = node.id,
                  outlineView.isItemExpanded(node) else { continue }
            ids.insert(id)
        }
        return ids
    }
    
    func applyExpansionState(to nodes: [HistoryNode], preferredExpandedIds: Set<String> = []) {
        guard let outlineView else { return }
        isApplyingExpansionState = true
        defer { isApplyingExpansionState = false }
        
        for node in nodes where node.isGroup {
            guard let id = node.id else { continue }
            let shouldExpand: Bool
            if preferredExpandedIds.contains(id) {
                shouldExpand = true
            } else {
                shouldExpand = node.collapsed != true
            }
            
            if shouldExpand {
                outlineView.expandItem(node, expandChildren: false)
                if let children = node.children {
                    applyExpansionState(to: children, preferredExpandedIds: preferredExpandedIds)
                }
            } else {
                outlineView.collapseItem(node, collapseChildren: true)
            }
        }
    }
    
    private func node(from item: Any?) -> HistoryNode? {
        item as? HistoryNode
    }
}

// MARK: - NSOutlineViewDataSource

extension HistoryOutlineController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = node(from: item) {
            return node.children?.count ?? 0
        }
        return roots.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = node(from: item) {
            return node.children![index]
        }
        return roots[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? HistoryNode)?.isGroup == true
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = item as? HistoryNode, let id = node.id else { return nil }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(id, forType: HistoryDragDrop.pasteboardType)
        return pasteboardItem
    }
}

// MARK: - NSOutlineViewDelegate

extension HistoryOutlineController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        HistoryTableRowView()
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? HistoryNode else { return nil }
        
        let cell: HistoryRowCellView
        if let reused = outlineView.makeView(withIdentifier: HistoryRowCellView.reuseIdentifier, owner: self) as? HistoryRowCellView {
            cell = reused
        } else {
            cell = HistoryRowCellView(frame: .zero)
        }
        let isRenaming = node.id == renamingGroupId
        cell.configure(
            with: node,
            isRenaming: isRenaming,
            editingDelegate: self
        ) { [weak self] in
            self?.handleDelete(node: node)
        }
        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        HistoryListLayout.rowHeight
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        true
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard isProgrammaticSelection == false, let outlineView else { return }
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? HistoryNode, let id = node.id else { return }
        actions.selectHistory(id: id)
    }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard isApplyingExpansionState == false,
              let node = notification.userInfo?["NSObject"] as? HistoryNode,
              let id = node.id else { return }
        actions.setGroupCollapsed(id: id, collapsed: false)
    }
    
    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard isApplyingExpansionState == false,
              let node = notification.userInfo?["NSObject"] as? HistoryNode,
              let id = node.id else { return }
        actions.setGroupCollapsed(id: id, collapsed: true)
    }
    
    // MARK: - Drag & drop
    
    func tableView(_ tableView: NSTableView, shouldStartDragFromRow row: Int, at point: NSPoint) -> Bool {
        guard let outlineView = tableView as? NSOutlineView,
              let cellView = outlineView.view(atColumn: 0, row: row, makeIfNecessary: true) as? HistoryRowCellView else {
            return true
        }
        let pointInCell = cellView.convert(point, from: outlineView)
        return cellView.shouldAllowDrag(from: pointInCell)
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard let draggedId = HistoryDragDrop.nodeId(from: info) else {
            updateDropTargetHighlight(groupId: nil)
            return []
        }
        
        if let target = item as? HistoryNode, target.id == draggedId {
            updateDropTargetHighlight(groupId: nil)
            return []
        }
        
        if index == NSOutlineViewDropOnItemIndex {
            guard let target = item as? HistoryNode,
                  target.isGroup,
                  let groupId = target.id,
                  actions.canMoveNode(draggedId, intoGroup: groupId) else {
                updateDropTargetHighlight(groupId: nil)
                return []
            }
            updateDropTargetHighlight(groupId: groupId)
            return .move
        }
        
        updateDropTargetHighlight(groupId: nil)
        
        let parentId = parentId(forProposedItem: item)
        guard isValidMove(draggedId: draggedId, toParentId: parentId) else { return [] }
        return .move
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let draggedId = HistoryDragDrop.nodeId(from: info) else { return false }
        defer {
            updateDropTargetHighlight(groupId: nil)
            draggingNodeId = nil
        }
        
        if index == NSOutlineViewDropOnItemIndex {
            guard let group = item as? HistoryNode,
                  group.isGroup,
                  let groupId = group.id,
                  actions.canMoveNode(draggedId, intoGroup: groupId) else {
                return false
            }
            actions.moveNodeIntoGroup(id: draggedId, groupId: groupId)
            return true
        }
        
        let parentId = parentId(forProposedItem: item)
        guard isValidMove(draggedId: draggedId, toParentId: parentId) else { return false }
        performDrop(draggedId: draggedId, parentId: parentId, insertIndex: index)
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        draggingNodeId = nil
        updateDropTargetHighlight(groupId: nil)
    }
    
}
