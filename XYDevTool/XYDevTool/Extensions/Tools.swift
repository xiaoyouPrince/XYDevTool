//
//  Tools.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/6/19.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Foundation

/// 获取一个随机 JSON 字符串
/// - Parameters:
///   - maxLayer: 最大的层级
///   - maxElementsPerLayer: 每层最大元素数量
/// - Returns: 返回 JOSN 字符串
func getRandomJSON(maxLayer: Int, maxElementsPerLayer: Int) -> String {
    var result = "{}"
    let dict = getRandomDict(maxLayer: maxLayer, maxElementsPerLayer: maxElementsPerLayer)
    do{
        let data = try JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions.prettyPrinted)
        let jsonStr = String(data: data, encoding: .utf8)
        result = jsonStr!
    }catch {
        return result
    }
    
    return result
}

func random(input: Int) -> Int{
    return Int(arc4random_uniform(UInt32(input)))
}

func getRandomString() -> String {
    
    var result = ""
    
    let keyLength = 5
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
//    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&()*+,-./:;<=>?@[]^_{}|~"
    
    for _ in 0..<keyLength {
        let offset = Int(arc4random_uniform(UInt32(letters.count)))
        let index = letters.index(letters.startIndex, offsetBy: offset)
        let char = letters[index...index]
        result.append(String(char))
    }
    
    return result
}

/// 随机获取一个value
/// - Returns: Bool/Double/Int/String/Array/Dict
fileprivate func getRandomValue(maxLayer: Int = 8, maxElementsPerLayer: Int = 3) -> Any {
    
    enum ValueType: UInt32, CaseIterable {
        case Bool
        case Double
        case Int
        case String
        case Array
        case Dict
    }
     
    let rawValue = arc4random_uniform(UInt32(ValueType.allCases.count))
    switch ValueType(rawValue: rawValue) {
    case .some(.Bool):
        return arc4random_uniform(2) == 0 ? false : true
    case .some(.Double):
        return Double(String(random(input: 10000)) + "." + String(random(input: 10))) as Any
    case .some(.Int):
        return random(input: 10000)
    case .some(.String):
        return getRandomString()
    case .some(.Array):
        // 这里就返回三个字符串/数字。 全部可能性展开，复杂度太高且没有必要
        if random(input: 2) == 1 {
            return [getRandomString(),getRandomString(),getRandomString()]
        }
        return [random(input: 10000),random(input: 10000),random(input: 10000)]
    case .some(.Dict):
        return getRandomDict(maxLayer: maxLayer-1, maxElementsPerLayer: maxElementsPerLayer)
    case .none:
        return "null"
    }
}

fileprivate func getRandomDict(maxLayer: Int, maxElementsPerLayer: Int) -> Dictionary<String, Any> {
    
    let maxLayer = max(random(input: maxLayer), 1)
    let maxElementsPerLayer = max(random(input: maxElementsPerLayer),1)
    
    var result: [String: Any] = [:]

    for _ in 0..<maxElementsPerLayer {
        let key = getRandomString()
        let value = getRandomValue(maxLayer: maxLayer, maxElementsPerLayer: maxElementsPerLayer)
        result[key] = value
    }
    
    return result
}
