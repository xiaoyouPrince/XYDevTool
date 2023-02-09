//
//  LeftView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/12/23.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Cocoa

class LeftView: NSVisualEffectView {
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    override init(frame frameRect: NSRect) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.xy_backgroundColor = .purple
        
        outlineView?.backgroundColor = .red
    }
    

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        
        outlineView?.backgroundColor = .red
    }
    
    
    
}
