//
//  JSONDecoder.swift
//  Model
//
//  Created by lei.ren on 2021/8/30.
//

import Foundation

public extension JSONDecoder {
    
    func decode<T: Model>(_ type: T.Type, from data: Data, keyPath: String?) throws -> T {
        userInfo.keyPath = keyPath
        return try decode(Box<T>.self, from: data).value
    }
}

struct ModelDecoder: Decoder {
    
    var codingPath: [CodingKey] {
        decoder.codingPath
    }
    
    var userInfo: [CodingUserInfoKey : Any] {
        decoder.userInfo
    }
    
    let decoder: Decoder
    
    let keyDecodingStrategy: [ModelKey: JSONKey]?
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(try _KeyedDecodingContainer(modelDecoder: self, keyDecodingStrategy: keyDecodingStrategy))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        try decoder.unkeyedContainer()
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        try decoder.singleValueContainer()
    }
}
