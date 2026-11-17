//
//  NetworkAuxiliaryWindows.swift
//  XYDevTool
//
//  设置 / 文档 / Mock 使用独立可缩放窗口，避免盖住网络主窗的固定 sheet。
//

import AppKit
import SwiftUI

final class NetworkAuxiliaryWindows: NSObject, NSWindowDelegate {
    private weak var dataModel: NetworkDataModel?
    
    private var settingsWindow: NSWindow?
    private var mockWindow: NSWindow?
    private var apiDocWindow: NSWindow?
    private var settingsHosting: NSViewController?
    private var mockHosting: NSViewController?
    private var apiDocHosting: NSViewController?
    
    init(dataModel: NetworkDataModel) {
        self.dataModel = dataModel
        super.init()
    }
    
    func showSettings() {
        guard let dataModel else { return }
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingController(
            rootView: SettingsView()
                .environmentObject(dataModel)
                .environment(dataModel.editor)
                .environment(dataModel.historyListUI)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        let window = makeWindow(
            title: "网络设置",
            size: NSSize(width: 520, height: 560),
            minSize: NSSize(width: 420, height: 360)
        )
        window.contentViewController = hosting
        window.delegate = self
        settingsHosting = hosting
        settingsWindow = window
        positionRelativeToNetworkWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showMock() {
        guard let dataModel else { return }
        if let mockWindow {
            mockWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingController(
            rootView: PanelMockView(mock: dataModel.mockController)
                .environmentObject(dataModel)
        )
        let window = makeWindow(
            title: "Mock 服务",
            size: NSSize(width: 760, height: 660),
            minSize: NSSize(width: 560, height: 420)
        )
        window.contentViewController = hosting
        window.delegate = self
        mockHosting = hosting
        mockWindow = window
        positionRelativeToNetworkWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showAPIDoc() {
        guard let dataModel else { return }
        if let apiDocWindow {
            apiDocWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingController(
            rootView: PanelAPIDocView()
                .environmentObject(dataModel)
        )
        let window = makeWindow(
            title: "接口文档",
            size: NSSize(width: 900, height: 720),
            minSize: NSSize(width: 640, height: 480)
        )
        window.contentViewController = hosting
        window.delegate = self
        apiDocHosting = hosting
        apiDocWindow = window
        positionRelativeToNetworkWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeAll() {
        settingsWindow?.delegate = nil
        mockWindow?.delegate = nil
        apiDocWindow?.delegate = nil
        settingsWindow?.close()
        mockWindow?.close()
        apiDocWindow?.close()
        settingsWindow = nil
        mockWindow = nil
        apiDocWindow = nil
        settingsHosting = nil
        mockHosting = nil
        apiDocHosting = nil
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow {
            settingsWindow = nil
            settingsHosting = nil
        } else if window === mockWindow {
            mockWindow = nil
            mockHosting = nil
        } else if window === apiDocWindow {
            apiDocWindow = nil
            apiDocHosting = nil
        }
    }
    
    private func makeWindow(title: String, size: NSSize, minSize: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = minSize
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
    
    private func positionRelativeToNetworkWindow(_ window: NSWindow) {
        let networkWindow = NSApp.windows.first(where: { $0.title == "网络请求" && $0 !== window })
        guard let parent = networkWindow else {
            window.center()
            return
        }
        var frame = window.frame
        let parentFrame = parent.frame
        frame.origin.x = parentFrame.maxX + 12
        frame.origin.y = parentFrame.maxY - frame.height
        if let screen = parent.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if frame.maxX > visible.maxX {
                frame.origin.x = max(visible.minX, parentFrame.minX - frame.width - 12)
            }
            if frame.minY < visible.minY {
                frame.origin.y = visible.minY + 20
            }
            if frame.maxY > visible.maxY {
                frame.origin.y = visible.maxY - frame.height
            }
        }
        window.setFrame(frame, display: false)
    }
}
