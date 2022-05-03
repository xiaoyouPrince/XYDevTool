//
//  Model+Decodable.swift
//  Model
//
//  Created by lei.ren on 2021/9/3.
//

import Foundation

internal protocol _JSONStringDictionaryDecodableMarker {
        
    static func decode(from decoder: Decoder) throws -> Decodable
}

extension Dictionary: _JSONStringDictionaryDecodableMarker where Key == String, Value: Model {
       
    static func decode(from decoder: Decoder) throws -> Decodable {
        
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        
        var dictionary = [String: Value]()
        
        for key in container.allKeys {

            let value = try container.decode(ModelBox<Value>.self, forKey: key).value
            dictionary[key.stringValue] = value
        }
        return dictionary
    }
}


internal protocol _JSONStringArrayDecodableMarker {
            
    static func decode(from decoder: Decoder) throws -> Decodable
}

extension Array: _JSONStringArrayDecodableMarker where Element: Model {
    
    static func decode(from decoder: Decoder) throws -> Decodable {
        
        var array = [Element]()
        var container = try decoder.unkeyedContainer()
        
        while !container.isAtEnd {
            let element = try container.decode(ModelBox<Element>.self).value
            array.append(element)
        }
        return array
    }
}
