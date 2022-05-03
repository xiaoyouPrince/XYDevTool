//
//  Model.swift
//  Model
//
//  Created by lei.ren on 2021/8/30.
//

import Foundation

/// `Model` 属性名
public typealias ModelKey = String

/// `JSON` 键名
public typealias JSONKey = String


public protocol Model: Codable {
    
    /// `Model` 映射完成完成回调
    mutating func didFinishMapping()
    
    /// 解码 `key` 策略
    static func keyDecodingStrategy() -> [ModelKey: JSONKey]
}

/// 默认实现
public extension Model {
    
    mutating func didFinishMapping() { }
    
    static func keyDecodingStrategy() -> [ModelKey: JSONKey] { [ : ] }
}

public extension Model {
    
    static func mapping<T: Model>(jsonData: Data,
                                  as type: T.Type,
                                  decoder: JSONDecoder,
                                  keyPath: String?) throws -> T {
        
        return try decoder.decode(type, from: jsonData, keyPath: keyPath)
    }
    
    static func mapping(jsonData: Data,
                        decoder: JSONDecoder = JSONDecoder(),
                        keyPath: String? = nil) -> Self? {
        do {
            return try mapping(jsonData: jsonData, as: self, decoder: decoder, keyPath: keyPath)
        } catch {
            return nil
        }
    }
    
    
    func toData() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
    
    func toString() -> String? {
        guard let data = toData() else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    func toDictionary() -> [String: Any]? {
        guard let data = toData() else {
            return nil
        }
        let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
        return json as? [String: Any]
    }
}

extension Array: Model where Element: Model {
    
    public static func mapping(jsonData: Data,
                               decoder: JSONDecoder = JSONDecoder(),
                               keyPath: String? = nil) -> Self? {
        do {
            return try mapping(jsonData: jsonData, as: [Element].self, decoder: decoder, keyPath: keyPath)
        } catch {
            return nil
        }
    }
}

extension Dictionary: Model where Key == String, Value: Model {
    
    public static func mapping(jsonData: Data,
                               decoder: JSONDecoder = JSONDecoder(),
                               keyPath: String? = nil) -> Self? {
        do {
            return try mapping(jsonData: jsonData, as: [String: Value].self, decoder: decoder, keyPath: keyPath)
        } catch {
            return nil
        }
    }
}
