//
//  HistoryRowCellView.swift
//  XYDevTool
//
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import AppKit

protocol HistoryRowCellEditingDelegate: AnyObject {
    func cellDidCommitRename(nodeId: String, name: String)
    func cellDidCancelRename()
}

final class HistoryRowCellView: NSTableCellView, NSTextFieldDelegate {
    
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("HistoryRowCell")
    
    weak var editingDelegate: HistoryRowCellEditingDelegate?
    var onDelete: (() -> Void)?
    
    private var editingNodeId: String?
    private var isEndingRename = false
    
    private let titleField: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingTail
        field.cell?.truncatesLastVisibleLine = true
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.backgroundColor = .clear
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private lazy var deleteButton: NSButton = {
        let image = NSImage(systemSymbolName: "trash", accessibilityDescription: "删除")
        let button = NSButton(image: image ?? NSImage(), target: self, action: #selector(deleteTapped))
        button.isBordered = false
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.contentTintColor = .systemRed
        button.translatesAutoresizingMaskIntoConstraints = false
        button.toolTip = "删除"
        return button
    }()
    
    private let deleteButtonSize = NetworkDataModel.historyRowHandleSize
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.reuseIdentifier
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        addSubview(titleField)
        addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: deleteButtonSize),
            deleteButton.heightAnchor.constraint(equalToConstant: deleteButtonSize),
            
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            titleField.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -4),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(
        with node: HistoryNode,
        isRenaming: Bool,
        editingDelegate: HistoryRowCellEditingDelegate?,
        onDelete: @escaping () -> Void
    ) {
        self.editingDelegate = editingDelegate
        self.onDelete = onDelete
        applyDisplayTitle(for: node)
        
        if isRenaming, let id = node.id {
            beginRenaming(nodeId: id, name: node.name ?? "")
        } else {
            resetTitleFieldStyle()
        }
    }
    
    func beginRenaming(nodeId: String, name: String) {
        editingNodeId = nodeId
        isEndingRename = false
        titleField.stringValue = name
        titleField.isEditable = true
        titleField.isSelectable = true
        titleField.isBezeled = true
        titleField.bezelStyle = .roundedBezel
        titleField.delegate = self
        
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            self.window?.makeFirstResponder(self.titleField)
            self.titleField.currentEditor()?.selectAll(nil)
        }
    }
    
    func shouldAllowDrag(from pointInCell: NSPoint) -> Bool {
        if editingNodeId != nil { return false }
        let pointInDelete = deleteButton.convert(pointInCell, from: self)
        return deleteButton.bounds.contains(pointInDelete) == false
    }
    
    // MARK: - NSTextFieldDelegate
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            finishRenaming(commit: true)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            finishRenaming(commit: false)
            return true
        }
        return false
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        finishRenaming(commit: true)
    }
    
    // MARK: - Private
    
    private func applyDisplayTitle(for node: HistoryNode) {
        let name = node.name ?? ""
        if node.isGroup, HistoryTree.subtreeContainsRequest(node) == false {
            titleField.stringValue = "\(name) (empty)"
        } else {
            titleField.stringValue = name
        }
    }
    
    private func finishRenaming(commit: Bool) {
        guard isEndingRename == false, let nodeId = editingNodeId else { return }
        isEndingRename = true
        
        let draft = titleField.stringValue
        editingNodeId = nil
        resetTitleFieldStyle()
        
        if commit {
            editingDelegate?.cellDidCommitRename(nodeId: nodeId, name: draft)
        } else {
            editingDelegate?.cellDidCancelRename()
        }
    }
    
    private func resetTitleFieldStyle() {
        titleField.delegate = nil
        titleField.isEditable = false
        titleField.isSelectable = false
        titleField.isBezeled = false
    }
    
    @objc private func deleteTapped() {
        onDelete?()
    }
}
