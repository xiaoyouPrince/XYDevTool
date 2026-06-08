//
//  HistoryOutlineController+Rename.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import AppKit

extension HistoryOutlineController: HistoryRowCellEditingDelegate, HistoryOutlineContextMenuProviding {
    
    func contextMenu(for item: Any, outlineView: NSOutlineView, row: Int) -> NSMenu? {
        guard let node = item as? HistoryNode,
              node.isGroup,
              let id = node.id else { return nil }
        
        if outlineView.selectedRow != row {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            actions.selectHistory(id: id)
        }
        
        return makeGroupContextMenu(groupId: id)
    }
    
    func makeGroupContextMenu(groupId: String) -> NSMenu {
        let menu = NSMenu()
        
        let renameItem = NSMenuItem(title: "重命名", action: #selector(historyMenuRename(_:)), keyEquivalent: "")
        renameItem.target = self
        renameItem.representedObject = groupId
        menu.addItem(renameItem)
        
        let deleteItem = NSMenuItem(title: "删除分组", action: #selector(historyMenuDeleteGroup(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = groupId
        menu.addItem(deleteItem)
        
        return menu
    }
    
    func configureRenameAndMenu(on outlineView: NSOutlineView) {
        outlineView.doubleAction = #selector(handleRowDoubleClick(_:))
        outlineView.target = self
    }
    
    @objc func handleRowDoubleClick(_ sender: NSOutlineView) {
        let row = sender.clickedRow >= 0 ? sender.clickedRow : sender.selectedRow
        guard row >= 0,
              let node = sender.item(atRow: row) as? HistoryNode,
              node.isGroup,
              let id = node.id else { return }
        beginRename(groupId: id, currentName: node.name ?? "")
    }
    
    func beginRename(groupId: String, currentName: String) {
        renamingGroupId = groupId
        guard let outlineView, let row = rowIndex(forNodeId: groupId, in: roots) else { return }
        outlineView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
    }
    
    func cellDidCommitRename(nodeId: String, name: String) {
        let groupId = renamingGroupId
        renamingGroupId = nil
        
        guard groupId == nodeId else { return }
        if let error = actions.renameGroup(id: nodeId, to: name) {
            showAlert(msg: error)
        }
    }
    
    func cellDidCancelRename() {
        renamingGroupId = nil
        guard let outlineView else { return }
        let expandedIds = captureExpandedGroupIds()
        outlineView.reloadData()
        applyExpansionState(to: roots, preferredExpandedIds: expandedIds)
        syncSelection(to: selectedId)
    }
    
    @objc func historyMenuRename(_ sender: NSMenuItem) {
        guard let id = menuItemNodeId(sender),
              let node = HistoryTree.findNode(id: id, in: actions.historyRoots())?.node,
              node.isGroup else { return }
        beginRename(groupId: id, currentName: node.name ?? "")
    }
    
    @objc func historyMenuDeleteGroup(_ sender: NSMenuItem) {
        guard let id = menuItemNodeId(sender),
              let node = HistoryTree.findNode(id: id, in: actions.historyRoots())?.node,
              node.isGroup else { return }
        handleDelete(node: node)
    }
    
    private func menuItemNodeId(_ item: NSMenuItem) -> String? {
        if let id = item.representedObject as? String { return id }
        return (item.representedObject as? NSString) as String?
    }
}
