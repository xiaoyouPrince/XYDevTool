//
//  UpgradeViewController.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/21.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Cocoa

class UpgradeViewController: NSViewController {
    @IBOutlet weak var verstionLab: NSTextField!
    @IBOutlet weak var currentVertionLab: NSTextField!
    @IBOutlet weak var descLab: NSTextField!
    @IBOutlet weak var upgradeBtn: NSButton!
    
    var versionInfo: Version?
    var currentVer: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "版本更新"
        verstionLab.stringValue = "最新版本: \(versionInfo?.tag_name ?? "unknown")"
        currentVertionLab.stringValue = "当前版本: \(currentVer ?? "unknown")"
        descLab.stringValue = "更新说明:\n" + "\(versionInfo?.body ?? "unknown")"
        upgradeBtn.title = "更新"
    }
    
    @IBAction func upgradeBtnAction(_ sender: NSButton) {
        if let htmlURL = versionInfo?.html_url,
            let url =  URL(string: htmlURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
