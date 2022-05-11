//
//  XYAlert.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/11.
//

import Cocoa

class XYAlert: NSView {

    @IBOutlet weak var iconView: NSButtonCell!
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var okBtn: NSButton!
    @IBOutlet weak var cancelBtn: NSButton!
    
    var okCallBack: (()->())?
    var cancelCallBack: (()->())?
    
    
    static let shared = XYAlert()
    
    static func showAlert(on View: NSView,
                          msg: String,
                          okCallBack: (()->())?,
                          cancelCallBack: (()->())?){
        
        shared.iconView.image = NSImage(named: "im")
        shared.textView.string = msg
        shared.okBtn.title = "确定"
        shared.cancelBtn.title = "取消"
        shared.okCallBack = okCallBack
        shared.cancelCallBack = cancelCallBack
    
        View.addSubview(shared)
        
        shared.frame = CGRect(x: 0, y: 0, width: 300, height: 240)
        shared.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    @IBAction func okClick(_ sender: Any) {
        okCallBack?()
    }
    
    @IBAction func cancelClick(_ sender: Any) {
        cancelCallBack?()
    }
    
}
