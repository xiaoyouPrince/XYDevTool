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

class JsonFormatterVC: NSViewController {
    
    @IBOutlet weak var textV: NSScrollView!
    var tv1: NSTextView!
    
    @IBOutlet weak var statusLabel: NSTextField!
    
    var lines = 0
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        if let tv1 = textV.documentView as? NSTextView {
            self.tv1 = tv1
        }
        
        tv1.delegate = self
        
    }
    
    @IBAction func okClick(_ sender: Any) {
        // 1. 字符串无法直接转换成json egg:"{\n    \"code\": 200,  =》 需要先保存文件，直接从file读取，然后转JSON
        // 2. 直接将完整的 JSON 转换为可读数据
        
        // 去掉空格和换行先
        var str = tv1.string.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去掉里面的转义字符
        str = str.replacingOccurrences(of: "\\", with: "")
        
        // 写入文件， Dict 读取文件
        let path = Bundle.main.resourcePath! + "/dict.json"
        try? str.write(toFile: path, atomically: true, encoding: .utf8)
        
        if let data = NSData(contentsOfFile: path){
            
            do {
                let dict =  try JSONSerialization.jsonObject(with: (data as Data), options: .fragmentsAllowed)
                let preData = try! JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
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




extension JsonFormatterVC: NSTextViewDelegate {
    
    func textViewDidChangeTypingAttributes(_ notification: Notification) {
//        print(notification)
    }
    
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        
        defer{
            
            let total = textView.string.reduce(0) { partialResult, char in
                if char == "\n" {
                    return partialResult + 1
                }
                else {
                    return partialResult
                }
            }
            
            self.lines = total
            print("-------\(total)-------")
        }
        
        print(replacementString)
        return true
    }
}
