//
//  HistoryOutlineController+Delete.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import AppKit

extension HistoryOutlineController {
    
    func handleDelete(node: HistoryNode) {
        guard let id = node.id else { return }
        
        if node.isGroup {
            presentDeleteGroupDialog(groupId: id, groupName: node.name ?? "未命名分组")
            return
        }
        
        let title = node.name ?? "未命名请求"
        if actions.isRequestLocked(id: id) {
            showAlert(msg: "您要移除的记录为【\(title)】它是锁定的记录，不能直接删除，需要先解除锁定")
            return
        }
        actions.removeHistory(id: id)
    }
    
    private func presentDeleteGroupDialog(groupId: String, groupName: String) {
        let alert = NSAlert()
        alert.messageText = "删除分组「\(groupName)」"
        alert.informativeText = "请选择删除方式"
        alert.addButton(withTitle: "仅删除分组")
        alert.addButton(withTitle: "删除分组及全部内容")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            actions.deleteGroup(id: groupId, unwrapOnly: true)
        case .alertSecondButtonReturn:
            let lockedCount = actions.lockedRequestCount(inSubtreeOf: groupId)
            if lockedCount > 0 {
                presentForceDeleteLockedDialog(groupId: groupId, lockedCount: lockedCount)
            } else {
                actions.deleteGroup(id: groupId, unwrapOnly: false)
            }
        default:
            break
        }
    }
    
    private func presentForceDeleteLockedDialog(groupId: String, lockedCount: Int) {
        let alert = NSAlert()
        alert.messageText = "该分组包含 \(lockedCount) 个锁定请求"
        alert.informativeText = "强制删除将忽略锁定并删除全部内容"
        alert.addButton(withTitle: "强制删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            actions.deleteGroup(id: groupId, unwrapOnly: false)
        }
    }
}
