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

    @IBAction func networkClick(_ sender: Any) {
        
//        let settingVC = NetResquestController()
////        settingVC.fileConfigChangedClosure = { [weak self] in
////            self?.generateClasses()
////        }
//        
//        presentAsModalWindow(settingVC)
        
        print("net work click")
        
        
//        let networkVC = NSHostingController(rootView: NetworkPanelView())
//        presentAsModalWindow(networkVC)
        
        openNewWindow()
        
        
    }
    
    func openNewWindow() {
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
    
}

