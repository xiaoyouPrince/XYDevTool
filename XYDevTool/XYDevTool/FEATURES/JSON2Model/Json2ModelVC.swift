//
//  Json2ModelVC.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/4/30.
//

import Foundation
import AppKit
//import SnapKit
import JavaScriptCore

class Json2ModelVC: NSViewController {
    
    var jsContext = JSContext()
    
    @IBOutlet weak var tv1: NSScrollView!
    @IBOutlet weak var okBtn: NSButton!
    @IBOutlet weak var tv2: NSScrollView!
    
    @IBOutlet weak var classPrefixView: NSView!
    @IBOutlet weak var classPrefix: NSTextField!
    
    @IBOutlet weak var comentView: NSView!
    @IBOutlet weak var conmentSwith: NSSwitch!
    
    @IBOutlet weak var baseClassView: NSView!
    @IBOutlet weak var baseClassTF: NSTextField!
    
    @IBOutlet weak var codingKeysView: NSView!
    @IBOutlet weak var codingKeysSwitch: NSSwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(NSScreen.main!.frame.size.width*0.5)
            make.height.greaterThanOrEqualTo(NSScreen.main!.frame.size.height*0.5)
        }
        
        tv1.snp.makeConstraints { make in
            make.left.top.equalToSuperview().offset(16)
            make.width.equalToSuperview().multipliedBy(0.5).offset(-80)
            make.bottom.equalToSuperview().offset(-26)
        }

        tv2.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.width.equalTo(tv1)
            make.bottom.equalTo(tv1)
        }
        
        okBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(20)
        }
        
        classPrefixView.snp.makeConstraints { make in
            make.top.equalTo(okBtn.snp.bottom).offset(20)
            make.centerX.equalTo(okBtn)
            make.left.equalTo(tv1.snp.right).offset(5)
            make.right.equalTo(tv2.snp.left).offset(-5)
            make.height.equalTo(30)
        }
        
        comentView.snp.makeConstraints { make in
            make.centerX.equalTo(classPrefixView)
            make.top.equalTo(classPrefixView.snp.bottom).offset(20)
            make.left.equalTo(tv1.snp.right).offset(5)
            make.right.equalTo(tv2.snp.left).offset(-5)
            make.height.equalTo(30)
        }
        
        baseClassView.snp.makeConstraints { make in
            make.centerX.equalTo(classPrefixView)
            make.top.equalTo(comentView.snp.bottom).offset(20)
            make.left.equalTo(tv1.snp.right).offset(5)
            make.right.equalTo(tv2.snp.left).offset(-5)
            make.height.equalTo(30)
        }
        
        codingKeysView.snp.makeConstraints { make in
            make.centerX.equalTo(classPrefixView)
            make.top.equalTo(baseClassView.snp.bottom).offset(20)
            make.left.equalTo(tv1.snp.right).offset(5)
            make.right.equalTo(tv2.snp.left).offset(-5)
            make.height.equalTo(53)
        }
    }
    
    @IBAction func okBtnClick(_ sender: NSButton) {
        
        print(classPrefix.stringValue)
        print(conmentSwith.state)
        print(baseClassTF.stringValue)
        print(codingKeysSwitch.state)
        
        guard let textV1 = tv1.documentView as? NSTextView,
        let textV2 = tv2.documentView as? NSTextView else {
            return
        }
        // textV1.string = "{\"name\":\"fdv\"}"
        
        // 1. 校验 tv1.string 是不是 JSON
        guard textV1.string.isEmpty == false,
        (try? JSONSerialization.data(withJSONObject: textV1.string, options: .fragmentsAllowed)) != nil else {
            textV2.string = "输入JSON格式不正确，请保证JSON格式正确性"
            return
        }
        
        guard
            let path = Bundle.main.path(forResource: "json2model", ofType: "js"),
            let jsData = NSData(contentsOfFile: path),
              let jsCode = String(data: jsData as Data, encoding: .utf8)
        else { return }
        
        // print(jsCode)
        
        let params = [
            "jsonString": textV1.string,
            "classPrefix": classPrefix.stringValue,
            "needComent": conmentSwith.state.rawValue,
            "baseClass": baseClassTF.stringValue,
            "codingKeys": codingKeysSwitch.state.rawValue
        ] as [String : Any]
        
        let paramsD = try? JSONSerialization.data(withJSONObject: params, options: .fragmentsAllowed)
        let paramsString = String.init(data: paramsD!, encoding: .utf8)!
        
        
        // 处理入参数
        let finishString = String(format: jsCode,
                                  paramsString
//                                  textV1.string,
//                                  classPrefix.stringValue
//                                  conmentSwith.state.rawValue,
//                                  baseClassTF.stringValue,
//                                  codingKeysSwitch.state.rawValue
        )
        
        print(params)
        
        
        // print(finishString)
        // Note: 每次更新 context，可以重新设置上下文中的变量，否则无法重复使用
        jsContext = JSContext()
        // Note: 这一步必须要执行，要将js代码运行到上下文中，后序才能正常查询内部全局代码
        jsContext?.evaluateScript(finishString)
    
        let j2m = jsContext?.objectForKeyedSubscript("json2model")
        let result = j2m?.call(withArguments: []).toString()
        
        textV2.string = result ?? ""
    }
}
