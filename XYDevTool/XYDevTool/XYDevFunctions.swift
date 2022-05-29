//
//  XYDevFunctions.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/3.
//

import Cocoa

public func showAlert(msg: String){
    
    let a = NSAlert()
    //a.icon = NSImage(named: "im")
    a.messageText = msg
    a.runModal()
}

extension Collection {
    
    func toData() -> Data? {
        if let data = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted) {
            return data
        }
        return nil
    }
    
    func toString() -> String? {
        if let data = toData(), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }
}

func srting2JsonObject(string: String) -> [String: Any]? {
    
    if string.isEmpty {
        return [:]
    }
    
    // 1. 字符串无法直接转换成json egg:"{\n    \"code\": 200,  =》 需要先保存文件，直接从file读取，然后转JSON
    // 2. 直接将完整的 JSON 转换为可读数据
    
    // 去掉空格和换行先
    var str = string.trimmingCharacters(in: .whitespacesAndNewlines)
    // 去掉里面的转义字符
    str = str.replacingOccurrences(of: "\\", with: "")
    
    // 写入文件， Dict 读取文件
    let path = Bundle.main.resourcePath! + "/dict.json"
    try? str.write(toFile: path, atomically: true, encoding: .utf8)
    
    if let data = NSData(contentsOfFile: path){
        
        do {
            if let dict =  try JSONSerialization.jsonObject(with: (data as Data), options: .topLevelDictionaryAssumed) as? [String: Any]{
                // "转换完成"
                return dict
            }
            
        }catch{
            
            print(error)
            let err = error as NSError
            let errMsg = err.userInfo.description
            showAlert(msg: errMsg)
        }
    }
    
    return nil
}

extension NSTextView {
    
    // 统一配置
    func setup() {
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isContinuousSpellCheckingEnabled = false
        self.allowsUndo = true
        self.setUpLineNumberView()
    }
}


#if os(iOS)
import UIKit
public typealias XYColor = UIColor
#endif
#if os(macOS)
import Cocoa
public typealias XYColor = NSColor
#endif

public func kHexColor(_ valueRGB: UInt) -> XYColor {
    return kHexColor(valueRGB, alpha: 1.0)
}

public func kHexColor(_ valueRGB: UInt, alpha: CGFloat) -> XYColor {
    return XYColor.init(
        red: CGFloat((valueRGB & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((valueRGB & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat((valueRGB & 0x0000FF) >> 0) / 255.0,
        alpha: alpha)
}

public func randomColor() -> XYColor {
    return XYColor.randomColor()
}

public extension XYColor {
    
    static var random: XYColor {
        return randomColor()
    }
    
    // MARK:-便利构造方法
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat){
        // MARK:-必须通过self调用显式的构造方法
        self.init(red: r / 255.0, green: g/255.0, blue: b/255.0, alpha: 1.0)
    }
    
    // MARK: - 返回一个随机色
    class func randomColor() -> XYColor {
        return XYColor.init(r: CGFloat(arc4random_uniform(255)), g: CGFloat(arc4random_uniform(255)), b: CGFloat(arc4random_uniform(255)))
    }
    
    @objc static func xy_getColor(hex: Int) -> XYColor {
        let r = ((CGFloat)(hex >> 16 & 0xFF))
        let g = ((CGFloat)(hex >> 8 & 0xFF))
        let b = ((CGFloat)(hex & 0xFF))
        let color = XYColor(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: 1.0)
        return color
    }
    
    @objc static func xy_getColor(red: Int, green: Int, blue: Int) -> XYColor {
        let r = (CGFloat)(red);
        let g = (CGFloat)(green);
        let b = (CGFloat)(blue);
        let color = XYColor(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: 1.0)
        return color
    }
}
