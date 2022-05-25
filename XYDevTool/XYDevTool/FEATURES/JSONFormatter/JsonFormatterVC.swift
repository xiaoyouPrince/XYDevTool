//
//  JsonFormatterVC.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/6.
//

//  功能
// 格式化 JSON
// 压缩 JSON 就是变成一行


import Cocoa
import Highlightr

class JsonFormatterVC: NSViewController {
    
    @IBOutlet weak var textV: NSScrollView!
    var tv1: NSTextView!
    
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
        // Do view setup here.
        
        if let tv1 = textV.documentView as? NSTextView {
            self.tv1 = tv1
        }
        
        tv1.setup()
        tv1.delegate = self
        JSONStorage.addLayoutManager(tv1.layoutManager!)
        
        themeBtn.removeAllItems()
        themeBtn.addItems(withObjectValues: highlightr.availableThemes())
        themeBtn.delegate = self
        themeBtn.isEditable = false
//        themeBtn.isSelectable = false
    }
    
    @IBAction func okClick(_ sender: Any) {
        
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
                
                tv1.string = resultStr!
                statusLabel.stringValue = "转换完成"
            }catch{
                
                print(error)
                let err = error as NSError
                statusLabel.stringValue = err.userInfo.description
            }
        }
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
