//
//  NSView+XYDev.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/12/22.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Foundation

public extension NSView {

    var backgroundColor: NSColor {
        set{
            wantsLayer = true
            layer?.backgroundColor = newValue.cgColor
        }
        get{
            NSColor(cgColor: layer?.backgroundColor ?? .clear) ?? .clear
        }
    }
}
 
