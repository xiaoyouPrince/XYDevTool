//
//  XYDevFunctions.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/3.
//

import Cocoa

public func showAlert(msg: String){
    
    let a = NSAlert()
    a.icon = NSImage(named: "im")
    a.messageText = msg
    a.runModal()
}

