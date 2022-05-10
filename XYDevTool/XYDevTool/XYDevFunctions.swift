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

extension Collection {
    
    func toData() -> Data? {
        if let data = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted) {
            return data
        }
        return nil
    }
    
    func toString() -> String? {
        if let data = toData(), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }
}

