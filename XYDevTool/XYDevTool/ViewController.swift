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

        AppLogger.shared.track(category: .navigation, name: "home_viewed")
        checkVersion()
    }
    
    private func checkVersion() {
        let operation = AppLogger.shared.begin(category: .update, name: "version_check")
        UpgradeUtils.newestVersion { (version) in
            guard let version else {
                operation.finish(result: .failure, metadata: ["stage": "load_release"])
                return
            }

            guard let tagName = version.tag_name,
                  let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                  let newVersion = Int(
                    tagName
                        .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                        .replacingOccurrences(of: ".", with: "")
                  ),
                  let currentVeriosn = Int(bundleVersion.replacingOccurrences(of: ".", with: "")) else {
                operation.finish(result: .failure, metadata: ["stage": "parse_version"])
                return
            }

            let updateAvailable = newVersion > currentVeriosn
            operation.finish(
                result: .success,
                metadata: ["updateAvailable": String(updateAvailable)]
            )

            if updateAvailable {
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
        trackFeatureOpened("json_formatter")
        openJsonFormatterWindow()
    }
    

    @IBAction func networkClick(_ sender: Any) {
        trackFeatureOpened("network")
        openNetworkWindow()
    }
    
    
    @IBAction func customServerClick(_ sender: Any) {
        trackFeatureOpened("custom_server")
        openNewWindow(with: NSRect(x: 0, y: 0, width: 800, height: 600), title: "自定义服务器", contentView: CustomServerView())
    }
    
    @IBAction func imageInspectorClick(_ sender: Any) {
        trackFeatureOpened("image_inspector")
        openNewWindow(with: NSRect(x: 0, y: 0, width: 800, height: 600), title: "ImageInspector", contentView: ImageInspector())
    }

    private func trackFeatureOpened(_ feature: String) {
        AppLogger.shared.track(
            category: .navigation,
            name: "feature_opened",
            metadata: ["feature": feature]
        )
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
        
        let dataModel = NetworkDataModel()
        let hostingController = NSHostingController(rootView:
            NetworkHostingRoot(dataModel: dataModel)
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
