//
//  Transform.swift
//  Model
//
//  Created by lei.ren on 2021/8/30.
//

import Foundation

public protocol TransformType {
    
    associatedtype Object
    
    associatedtype Value: Codable
    
    static func decode(from value: Value) throws -> Object
    
    static func encode(to object: Object) throws  -> Value
}

@propertyWrapper
public struct Transform<T: TransformType>: Model {
    
    public var wrappedValue: T.Object
    
    public init(from decoder: Decoder) throws {
        
        let value = try T.Value(from: decoder)
        
        wrappedValue = try T.decode(from: value)
    }
    
    public func encode(to encoder: Encoder) throws {
        
        let encodable = try T.encode(to: wrappedValue)
        var container = encoder.singleValueContainer()
        try container.encode(encodable)
    }
}
