//
//  JsonFormatterVC.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/6.
//

// 参考博客
// https://blog.csdn.net/weixin_41483813/article/details/82622742

//按下按键
func keyboardKeyDown(key: CGKeyCode) {

    let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
    let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
    event?.post(tap: CGEventTapLocation.cghidEventTap)
    print("key \(key) is down")
}

//松开按键
func keyboardKeyUp(key: CGKeyCode) {
    let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
    let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
    event?.post(tap: CGEventTapLocation.cghidEventTap)
    print("key \(key) is released")
}

/// 空格和删除空格，模拟一次键盘事件
func spaceKeyDownAndDelete() {
    keyboardKeyDown(key: 0x31)
    keyboardKeyUp(key: 0x31)
    keyboardKeyDown(key: 0x33)
    keyboardKeyUp(key: 0x33)
}

import Cocoa
import Highlightr

class JsonFormatterVC: NSViewController {
    
    @IBOutlet var tv1: NSTextView!
    
    @IBOutlet weak var themeBtn: NSComboBox!
    
    @IBOutlet weak var statusLabel: NSTextField!
    
    private let highlightr = Highlightr()!
    private lazy var JSONStorage: CodeAttributedString = {
        let storage = CodeAttributedString()
        storage.highlightr.setTheme(to: "tomorrow-night-bright")
        storage.highlightr.theme.codeFont = NSFont(name: "Menlo", size: 14)
        storage.language = "json"
        return storage
    }()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tv1.setup()
        tv1.delegate = self
        JSONStorage.addLayoutManager(tv1.layoutManager!)
        
        themeBtn.removeAllItems()
        themeBtn.addItems(withObjectValues: highlightr.availableThemes())
        themeBtn.delegate = self
        themeBtn.isEditable = false
        themeBtn.isSelectable = true
        
        // 设置默认主题，这个后面可以考虑放到用户偏好设置中,这里触发代理设置主题
        themeBtn.selectItem(at: 9)
    }
    
    func setResult(string: String, desc: String) {
        tv1.string = string
        spaceKeyDownAndDelete()
        statusLabel.stringValue = desc + "完成"
    }
    
    @IBAction func okClick(_ sender: NSButton) {
        
        // 去掉空格和换行先
        let str = tv1.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 字符串无法直接转换成json egg:"{\n    \"code\": 200 }
        if str.first == "\"" { // 字符串开头，不支持格式化
            statusLabel.stringValue = "纯字符串无法转换"
            return
        }
        
        if let data = str.data(using: .utf8) {
            do {
                let dict =  try JSONSerialization.jsonObject(with: (data as Data), options: .fragmentsAllowed)
                let preData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                let resultStr = String(data: preData, encoding: .utf8)
                
                setResult(string: resultStr!, desc: sender.title)
                
            }catch{
                
                print(error)
                let err = error as NSError
                statusLabel.stringValue = err.userInfo.description
            }
        }
    }
    
    
    @IBAction func compressionAction(_ sender: NSButton) {
        
        let str = tv1.string.components(separatedBy: CharacterSet.whitespacesAndNewlines).joined(separator: "")
        
        setResult(string: str, desc: sender.title)
    }
    
    
}


extension JsonFormatterVC: NSComboBoxDelegate {
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        
        let theme = highlightr.availableThemes()[themeBtn.indexOfSelectedItem]

        JSONStorage.highlightr.setTheme(to: theme)
        JSONStorage.highlightr.theme.codeFont = NSFont(name: "Menlo", size: 14)
    }
}


extension JsonFormatterVC: NSTextViewDelegate {
    
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let value = link as? String,
           let url = URL(string: value) {
            NSWorkspace.shared.open(url)
        }
        
        return true
    }
}
