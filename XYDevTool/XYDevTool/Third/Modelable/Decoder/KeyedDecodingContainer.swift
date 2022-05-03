//
//  KeyedDecodingContainer.swift
//  Model
//
//  Created by lei.ren on 2021/8/30.
//

import Foundation

extension KeyedDecodingContainer {
    
    func decode<T: Decodable>(forKey key: Key, defaultValue: @autoclosure () -> T) throws -> T {
        let value = try? decodeIfPresent(T.self, forKey: key)
        return value ?? defaultValue()
    }
}

internal class _KeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    
    var codingPath: [CodingKey] {
        keyedContainer.codingPath
    }
    
    var allKeys: [Key] {
        keyedContainer.allKeys.compactMap { Key(stringValue: $0.stringValue) }
    }
    
    let keyedContainer: KeyedDecodingContainer<AnyCodingKey>
    
    let keyDecodingStrategy: [ModelKey: JSONKey]?
    
    init(modelDecoder: ModelDecoder, keyDecodingStrategy: [ModelKey: JSONKey]?) throws {
        
        self.keyDecodingStrategy = keyDecodingStrategy
        
        self.keyedContainer = try modelDecoder.decoder.container(keyedBy: AnyCodingKey.self)
    }
    
    func contains(_ key: Key) -> Bool {
        guard let (container, key) = try? nestedContainer(for: key) else {
            return false
        }
        return container.contains(key)
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        let (container, key) = try nestedContainer(for: key)
        return try container.decodeNil(forKey: key)
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: false)
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: "")
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        let (container, key) = try nestedContainer(for: key)
        return try container.decode(forKey: key, defaultValue: 0)
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        let (container, key) = try nestedContainer(for: key)
        do {
            return try container.decode(ModelBox<T>.self, forKey: key).value
        } catch {
            guard let defaultType = T.self as? DefaultValue.Type,
                  let value = defaultType.defaultValue as? T else {
                      throw error
                  }
            return value
        }
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try keyedContainer.nestedContainer(keyedBy: type, forKey: key.anyCodingKey)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try keyedContainer.nestedUnkeyedContainer(forKey: key.anyCodingKey)
    }
    
    func superDecoder() throws -> Decoder {
        try keyedContainer.superDecoder()
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        try keyedContainer.superDecoder(forKey: AnyCodingKey(stringValue: key.stringValue, intValue: nil))
    }
}


extension _KeyedDecodingContainer {
    
    func nestedContainer(for key: Key) throws -> (KeyedDecodingContainer<AnyCodingKey>, AnyCodingKey) {
        let keyString = key.stringValue
        return try nestedContainer(for: keyString)
    }
    
    func nestedContainer(for key: String) throws -> (KeyedDecodingContainer<AnyCodingKey>, AnyCodingKey) {
        
        var keyPath = (keyDecodingStrategy?[key] ?? key).nestedKeys
        
        var container = keyedContainer
        let key = keyPath.removeLast()
        
        try keyPath.forEach {
            container = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: $0)
        }
        return (container, key)
    }
}
