//
//  XYAlert.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/11.
//

import Cocoa

protocol NibLoadable {
    static var nibName: String? { get }
    static func createFromNib(in bundle: Bundle) -> Self?
}

extension NibLoadable where Self: NSView {

    static var nibName: String? {
         return String(describing: Self.self)
    }

    static func createFromNib(in bundle: Bundle = Bundle.main) -> Self? {
         guard let nibName = nibName else { return nil }
         var topLevelArray: NSArray? = nil
         bundle.loadNibNamed(NSNib.Name(nibName), owner: self, topLevelObjects: &topLevelArray)
         guard let results = topLevelArray else { return nil }
         let views = Array<Any>(results).filter { $0 is Self }
         return views.last as? Self
    }
}

class XYAlert: NSView, NibLoadable {

    @IBOutlet weak var iconView: NSButtonCell!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var okBtn: NSButton!
    @IBOutlet weak var cancelBtn: NSButton!
    
    var okCallBack: (()->())?
    var cancelCallBack: (()->())?
    
    override func awakeFromNib() {
        
        let view = NSView(frame: .zero)
        self.addSubview(view)
//        view.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//        }
        view.layer?.backgroundColor = NSColor.red.cgColor
        
    }
    
    static func showAlert(on View: NSView,
                          msg: String,
                          okCallBack: (()->())?,
                          cancelCallBack: (()->())?){
        
        let shared = XYAlert.createFromNib()!
        shared.iconView.image = NSImage(named: "im")
        shared.label.stringValue = msg
        shared.okBtn.title = "确定"
        shared.cancelBtn.title = "取消"
        shared.okCallBack = okCallBack
        shared.cancelCallBack = cancelCallBack
        shared.layer?.backgroundColor = NSColor.white.cgColor
    
        View.addSubview(shared)
        
        shared.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 343, height: 200))
        }
    }
    
    @IBAction func okClick(_ sender: Any) {
        okCallBack?()
        removeFromSuperview()
    }
    
    @IBAction func cancelClick(_ sender: Any) {
        cancelCallBack?()
        removeFromSuperview()
    }
    
}
