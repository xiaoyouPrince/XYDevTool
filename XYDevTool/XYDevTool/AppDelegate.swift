//
//  AppDelegate.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/4/30.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(category: "app")

    func applicationWillFinishLaunching(_ notification: Notification) {
        // App 可在这里调整安全选项，或追加其他 LogBackendPlugin。
        let logSecurityOptions = LogSecurityOptions.default
        LocalLogService.shared.configure(
            plugins: [LogPrivacyPlugin(options: logSecurityOptions)]
        )
        LoggingSystem.configure(handler: LocalLogService.shared)
        XYNetTool.delegate = XYNetToolLogAdapter.shared
        LocalLogService.shared.startSession()
    }


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        HelpMenuController.shared.install()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        LocalLogService.shared.finishSession()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
//https://www.jianshu.com/p/80b2b1c46d3b
    // 直接干死
//    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
//        return true
//    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        logger.event(
            "app.reopened",
            fields: ["hadVisibleWindows": String(flag)]
        )
        if flag == false {
            for win in sender.windows {
                win.makeKeyAndOrderFront(self)
            }
        }
        return true
    }


}
