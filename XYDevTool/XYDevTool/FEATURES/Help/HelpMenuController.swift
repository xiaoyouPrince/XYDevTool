//
//  HelpMenuController.swift
//  XYDevTool
//

import AppKit
import SwiftUI

@MainActor
final class HelpMenuController: NSObject {
    
    static let shared = HelpMenuController()
    
    private let state = HelpPresentationState()
    private var window: NSWindow?
    private weak var hostingController: NSHostingController<HelpView>?
    
    private override init() {
        super.init()
    }
    
    func install() {
        guard let helpMenu = NSApp.helpMenu else { return }
        
        helpMenu.removeAllItems()
        
        addMenuItem(to: helpMenu, title: "XYDevTool 帮助", action: #selector(showOverviewHelp(_:)), keyEquivalent: "?")
        addMenuItem(to: helpMenu, title: "快速开始", action: #selector(showGettingStartedHelp(_:)))
        helpMenu.addItem(.separator())
        addMenuItem(to: helpMenu, title: "网络请求工具说明", action: #selector(showNetworkHelp(_:)))
        addMenuItem(to: helpMenu, title: "JSON 格式化说明", action: #selector(showJSONFormatterHelp(_:)))
        addMenuItem(to: helpMenu, title: "JSON 转 Model 说明", action: #selector(showJSON2ModelHelp(_:)))
        helpMenu.addItem(.separator())
        addMenuItem(to: helpMenu, title: "运行日志…", action: #selector(showRuntimeLogs(_:)))
        addMenuItem(to: helpMenu, title: "在 Finder 中显示日志", action: #selector(revealRuntimeLogs(_:)))
        helpMenu.addItem(.separator())
        addMenuItem(to: helpMenu, title: "检查更新…", action: #selector(openReleases(_:)))
        addMenuItem(to: helpMenu, title: "GitHub 仓库", action: #selector(openGitHub(_:)))
    }
    
    func show(topic: HelpTopic) {
        state.selectedTopic = topic
        
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingController(rootView: HelpView(state: state))
        hostingController = hosting
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "XYDevTool 帮助"
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = hosting.view
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        window = newWindow
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func addMenuItem(to menu: NSMenu, title: String, action: Selector, keyEquivalent: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        menu.addItem(item)
    }
    
    @objc private func showOverviewHelp(_ sender: Any?) {
        show(topic: .overview)
    }
    
    @objc private func showGettingStartedHelp(_ sender: Any?) {
        show(topic: .gettingStarted)
    }
    
    @objc private func showNetworkHelp(_ sender: Any?) {
        show(topic: .networkTool)
    }
    
    @objc private func showJSONFormatterHelp(_ sender: Any?) {
        show(topic: .jsonFormatter)
    }
    
    @objc private func showJSON2ModelHelp(_ sender: Any?) {
        show(topic: .json2Model)
    }

    @objc private func showRuntimeLogs(_ sender: Any?) {
        LogViewerController.shared.show()
    }

    @objc private func revealRuntimeLogs(_ sender: Any?) {
        LocalLogService.shared.revealLogDirectory()
    }
    
    @objc private func openGitHub(_ sender: Any?) {
        NSWorkspace.shared.open(HelpDocumentStore.githubURL)
    }
    
    @objc private func openReleases(_ sender: Any?) {
        NSWorkspace.shared.open(HelpDocumentStore.releasesURL)
    }
}
