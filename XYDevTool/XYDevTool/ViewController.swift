//
//  ViewController.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/4/30.
//

import Cocoa
import SwiftUI

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkVersion()
    }
    
    private func checkVersion() {
        UpgradeUtils.newestVersion { (version) in
            guard let tagName = version?.tag_name,
                  let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                  let newVersion = Int(tagName.replacingOccurrences(of: ".", with: "")),
                  let currentVeriosn = Int(bundleVersion.replacingOccurrences(of: ".", with: "")) else {
                return
            }
            
            if newVersion > currentVeriosn {
                let upgradeVc = UpgradeViewController()
                upgradeVc.versionInfo = version
                upgradeVc.currentVer = bundleVersion
                self.presentAsModalWindow(upgradeVc)
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func jsonFormatterClick(_ sender: Any) {
        openJsonFormatterWindow()
    }
    

    @IBAction func networkClick(_ sender: Any) {
        openNetworkWindow()
    }
    
    
    @IBAction func customServerClick(_ sender: Any) {
        openNewWindow(with: NSRect(x: 0, y: 0, width: 800, height: 600), title: "自定义服务器", contentView: CustomServerView())
    }
    
}

extension ViewController {
    
    func openJsonFormatterWindow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false)
        
        newWindow.center()
        newWindow.title = "JSON格式化"
        newWindow.isReleasedWhenClosed = false
        
        let hostingController = NSHostingController(rootView:
                                                        JSONFormatterView()
                                                    
        )
        newWindow.contentView = hostingController.view
        
        let windowController = NSWindowController(window: newWindow)
        windowController.showWindow(self)
    }
    
    func openNetworkWindow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false)
        
        newWindow.center()
        newWindow.title = "网络请求"
        newWindow.isReleasedWhenClosed = false
        
        let hostingController = NSHostingController(rootView:
                                                        NetworkPanelView()
            .environmentObject(NetworkDataModel())
                                                    
        )
        newWindow.contentView = hostingController.view
        
        let windowController = NSWindowController(window: newWindow)
        windowController.showWindow(self)
    }
    
    func openNewWindow<Content: View>(with contentRect: NSRect, title: String, contentView: Content) {
        let newWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false)
        
        newWindow.center()
        newWindow.title = title
        newWindow.isReleasedWhenClosed = false
        
        let hostingController = NSHostingController(rootView: contentView)
        newWindow.contentView = hostingController.view
        
        let windowController = NSWindowController(window: newWindow)
        windowController.showWindow(self)
    }
}

