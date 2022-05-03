//
//  Box.swift
//  Model
//
//  Created by lei.ren on 2021/8/31.
//

import Foundation

struct Box<Value: Model>: Decodable {
    
    let value: Value
    
    init(from decoder: Decoder) throws {
        
        guard var keyPath = decoder.userInfo.keyPath?.nestedKeys else {
            value = try decoder.singleValueContainer().decode(ModelBox<Value>.self).value
            return
        }
        
        var container = try decoder.container(keyedBy: AnyCodingKey.self)
        let key = keyPath.removeLast()
        
        try keyPath.forEach {
            container = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: $0)
        }
        
        value = try container.decode(ModelBox<Value>.self, forKey: key).value
    }
}

struct ModelBox<Value: Decodable>: Decodable {
    
    let value: Value
    
    init(from decoder: Decoder) throws {
        if let arrayType = Value.self as? _JSONStringArrayDecodableMarker.Type,
           let arrayValue = try arrayType.decode(from: decoder) as? Value {
            
            self.value = arrayValue
            return
        }
        
        if let dictionaryType = Value.self as? _JSONStringDictionaryDecodableMarker.Type,
           let dictionaryValue = try dictionaryType.decode(from: decoder) as? Value {
            
            self.value = dictionaryValue
            return
        }
        
        let keyDecodingStrategy = (Value.self as? Model.Type)?.keyDecodingStrategy()
        
        let value = try Value(from: ModelDecoder(decoder: decoder, keyDecodingStrategy: keyDecodingStrategy))
        
        guard var model = value as? Model else {
            self.value = value
            return
        }
        
        model.didFinishMapping()
        
        if let value = model as? Value {
            self.value = value
        } else {
            throw DecodingError.typeMismatch(Value.self, .init(codingPath: decoder.codingPath, debugDescription: String("类型转换失败 \(Value.self)"), underlyingError: nil))
        }
    }
}
