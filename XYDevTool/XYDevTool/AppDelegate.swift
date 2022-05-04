//
//  AppDelegate.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/4/30.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
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
        if flag == false {
            for win in sender.windows {
                win.makeKeyAndOrderFront(self)
            }
        }
        return true
    }


}

