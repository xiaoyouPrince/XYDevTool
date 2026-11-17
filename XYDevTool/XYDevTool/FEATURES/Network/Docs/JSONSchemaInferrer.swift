//
//  JSONSchemaInferrer.swift
//  XYDevTool
//

import Foundation

struct APIDocField: Identifiable, Equatable {
    var id: String { path }
    let path: String
    let typeName: String
    let example: String
}

enum JSONSchemaInferrer {
    static func fields(from json: Any, prefix: String = "") -> [APIDocField] {
        var result: [APIDocField] = []
        appendFields(json, prefix: prefix, into: &result)
        return result
    }
    
    static func fields(fromJSONString text: String) -> [APIDocField] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        return fields(from: json)
    }
    
    private static func appendFields(_ value: Any, prefix: String, into result: inout [APIDocField]) {
        if let dict = value as? [String: Any] {
            if prefix.isEmpty == false {
                result.append(
                    APIDocField(
                        path: prefix,
                        typeName: "object",
                        example: "{…}"
                    )
                )
            }
            for key in dict.keys.sorted() {
                let next = prefix.isEmpty ? key : "\(prefix).\(key)"
                appendFields(dict[key] as Any, prefix: next, into: &result)
            }
            return
        }
        
        if let array = value as? [Any] {
            let itemPath = prefix.isEmpty ? "[]" : "\(prefix)[]"
            result.append(
                APIDocField(
                    path: prefix.isEmpty ? "[]" : prefix,
                    typeName: "array(\(array.count))",
                    example: "[…]"
                )
            )
            if let first = array.first {
                appendFields(first, prefix: itemPath, into: &result)
            }
            return
        }
        
        guard prefix.isEmpty == false else { return }
        result.append(
            APIDocField(
                path: prefix,
                typeName: typeName(of: value),
                example: scalarExample(value)
            )
        )
    }
    
    private static func typeName(of value: Any) -> String {
        switch value {
        case is NSNull:
            return "null"
        case is String:
            return "string"
        case is Bool:
            return "boolean"
        case let number as NSNumber:
            // Bool is bridged to NSNumber on Apple platforms
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return "boolean"
            }
            let doubleValue = number.doubleValue
            if doubleValue.rounded() == doubleValue {
                return "integer"
            }
            return "number"
        default:
            return "unknown"
        }
    }
    
    private static func scalarExample(_ value: Any) -> String {
        switch value {
        case is NSNull:
            return "null"
        case let string as String:
            let trimmed = string.count > 80 ? String(string.prefix(77)) + "..." : string
            return trimmed
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        default:
            return String(describing: value)
        }
    }
}
