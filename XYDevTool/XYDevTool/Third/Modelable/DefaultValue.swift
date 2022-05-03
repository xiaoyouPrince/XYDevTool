//
//  DefaultValue.swift
//  Model
//
//  Created by lei.ren on 2021/8/19.
//

import Foundation

public protocol DefaultValue {
    
    static var defaultValue: Self { get }
}

extension Dictionary: DefaultValue {
    public static var defaultValue: Dictionary { [:] }
}

extension Array: DefaultValue {
    public static var defaultValue: Array { [] }
}
