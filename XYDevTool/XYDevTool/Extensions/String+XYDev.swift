//
//  String+XYDev.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/6/6.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Foundation

extension String {
    
    /// 添加转义
    /// - Returns: 对于特殊字符进行转义
    public func addEscape() -> String {
        var result = removeEscape()
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        return result
    }
    
    /// 去除转义
    /// - Returns: 去除字符串内的转义字符
    public func removeEscape() -> String {
        
        let orign = self
        var result = ""
        
        // 0. 首尾是 \" 的字符串
        result = orign.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if result.hasPrefix("\"") {
            let firstIndex = result.startIndex...result.startIndex
            result = result.replacingCharacters(in: firstIndex, with: "")
        }
        if result.hasSuffix("\"") {
            let firstIndex = result.index(before: result.endIndex)..<result.endIndex
            result = result.replacingCharacters(in: firstIndex, with: "")
        }
        
        // 1. 去除换行 \n
        result = result.replacingOccurrences(of: "\\n", with: "")
        
        // 2. 去除 \
        result = result.replacingOccurrences(of: "\\", with: "")
        return result
    }
    
    /// 将字符串中的汉字字符转换成 Unicode 编码
    /// - Returns: 你好 -> \u4f60\u597d
    public func chinese2Unicode() -> String {
        self.unicodeScalars.map({ char in
            if char.isASCII {
                return "\(char)"
            }else{
                
                if (char.escaped(asASCII: true).count) == 8 {
                    let rmL = char.escaped(asASCII: true).replacingOccurrences(of: "{", with: "")
                    return rmL.replacingOccurrences(of: "}", with: "")
                }else
                {
                    return "\(char)"
                }
            }}).joined(separator: "")
    }
    
    /// 将字符串中的中文 Unicode 转换为汉字
    /// - Returns: \u4f60\u597d -> 你好
    public func unicode2Chinese() -> String {
        func convertHex2Decimal(hex: Character) -> Int {
            let orign = hex.lowercased()
            var result = 0
            switch orign {
            case "a":
                result = 10
            case "b":
                result = 11
            case "c":
                result = 12
            case "d":
                result = 13
            case "e":
                result = 14
            case "f":
                result = 15
            default:
                result = Int(orign) ?? 0
            }
            //print("\(orign) -> \(result)")
            return result
        }
        
        
        var result = self as NSString
        
        let regx = try? NSRegularExpression(pattern: "\\\\u[\\d|a-f]{4}", options: .caseInsensitive)
        if let matches = regx?.matches(in: self, range: NSRange(location: 0, length: self.count)) {
            for m in matches.reversed() {
                let subStr = result.substring(with: m.range)
                // \u4F60
                
                let n1 = (subStr as NSString).substring(with: NSRange(location: 2, length: 1)).first!
                let n2 = (subStr as NSString).substring(with: NSRange(location: 3, length: 1)).first!
                let n3 = (subStr as NSString).substring(with: NSRange(location: 4, length: 1)).first!
                let n4 = (subStr as NSString).substring(with: NSRange(location: 5, length: 1)).first!
                
                var hexValue = 0
                hexValue += convertHex2Decimal(hex: n1) * 16*16*16
                hexValue += convertHex2Decimal(hex: n2) * 16*16
                hexValue += convertHex2Decimal(hex: n3) * 16
                hexValue += convertHex2Decimal(hex: n4)
                let a = Unicode.Scalar(hexValue)!
                result = result.replacingCharacters(in: m.range, with: String(a)) as NSString
            }
        }
        
        return result as String
    }
}

import CommonCrypto //MD5
public extension String {
    /* #####################MD5实现########################### */
    /**
     - returns: the String, as an MD5 hash.
     */
    var md5: String {
        let str = self.cString(using: String.Encoding.utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: String.Encoding.utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        CC_MD5(str!, strLen, result)
        
        let hash = NSMutableString()
        
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.deallocate()
        return hash as String
    }
}

