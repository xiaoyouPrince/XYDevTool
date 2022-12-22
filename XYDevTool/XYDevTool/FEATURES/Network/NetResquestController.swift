//
//  NetResquestController.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/12/21.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Cocoa

class NetResquestController: NSViewController {

    @IBOutlet var topView: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        view.layer?.backgroundColor = .black
        
        view.snp.makeConstraints { make in
            make.size.greaterThanOrEqualTo(CGSize(width: 800, height: 600))
        }
        
        view.addSubview(topView)
        topView.backgroundColor = .init(r: 123, g: 161, b: 208)//.random
        topView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            //make.height.equalTo(90)
        }
    }
    
}
