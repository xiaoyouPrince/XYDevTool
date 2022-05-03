//
//  AnyCodingKey.swift
//  Model
//
//  Created by lei.ren on 2021/8/30.
//

import Foundation

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }
    
    init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }
    
    static let `super` = AnyCodingKey(stringValue: "super")!
}

extension CodingKey {
    
    var anyCodingKey: AnyCodingKey {
        AnyCodingKey(stringValue: stringValue, intValue: intValue)
    }
}

extension String {
    
    var nestedKeys: [AnyCodingKey] {
        components(separatedBy: ".").compactMap(AnyCodingKey.init)
    }
}

private let infoKey = CodingUserInfoKey(rawValue: "JSONKeyPath")!

extension Dictionary where Key == CodingUserInfoKey, Value == Any {
    
    var keyPath: String? {
        set {
            self[infoKey] = newValue
        }
        
        get {
            self[infoKey] as? String
        }
    }
}
