//
//  AnnotatedJSONRenderer.swift
//  XYDevTool
//
//  将 JSON 样本渲染为「带行内 // 注释」的文档体，贴近后台手写接口说明风格。
//

import Foundation

enum AnnotatedJSONRenderer {
    /// 同质对象数组最多完整展开的元素数；其余折叠为注释。
    private static let maxArraySamples = 2
    private static let commentColumn = 44
    
    static func render(fromJSONString text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return render(json)
    }
    
    static func render(_ value: Any) -> String {
        renderLines(value, indent: 0, trailingComment: nil).joined(separator: "\n")
    }
    
    private static func renderLines(_ value: Any, indent: Int, trailingComment: String?) -> [String] {
        let pad = String(repeating: "    ", count: indent)
        
        if let dict = value as? [String: Any] {
            if dict.isEmpty {
                return [annotated("\(pad){}", trailingComment)]
            }
            var lines = [annotated("\(pad){", trailingComment)]
            let keys = dict.keys.sorted()
            for (index, key) in keys.enumerated() {
                let isLast = index == keys.count - 1
                let child = dict[key] as Any
                let keyPrefix = "\(pad)    \"\(escapeString(key))\": "
                let comment = commentForValue(child)
                lines.append(contentsOf: renderKeyed(child, keyPrefix: keyPrefix, indent: indent + 1, comment: comment, comma: !isLast))
            }
            lines.append("\(pad)}")
            return lines
        }
        
        if let array = value as? [Any] {
            if array.isEmpty {
                return [annotated("\(pad)[]", trailingComment)]
            }
            var lines = [annotated("\(pad)[", trailingComment ?? "array(\(array.count))")]
            let sampleCount = min(array.count, maxArraySamples)
            for index in 0..<sampleCount {
                let isLastSample = index == sampleCount - 1
                let needsComma = !isLastSample || array.count > sampleCount
                let childIndent = indent + 1
                let childPad = String(repeating: "    ", count: childIndent)
                let childLines = renderLines(array[index], indent: childIndent, trailingComment: nil)
                if var last = childLines.last {
                    var body = Array(childLines.dropLast())
                    if needsComma { last += "," }
                    body.append(last)
                    lines.append(contentsOf: body)
                } else {
                    lines.append(annotated("\(childPad)null", nil) + (needsComma ? "," : ""))
                }
            }
            if array.count > sampleCount {
                lines.append("\(pad)    // … 另有 \(array.count - sampleCount) 项，结构相同")
            }
            lines.append("\(pad)]")
            return lines
        }
        
        return [annotated("\(pad)\(scalarLiteral(value))", trailingComment)]
    }
    
    private static func renderKeyed(
        _ value: Any,
        keyPrefix: String,
        indent: Int,
        comment: String?,
        comma: Bool
    ) -> [String] {
        if value is [String: Any] || value is [Any] {
            let lines = renderLines(value, indent: indent, trailingComment: comment)
            guard let first = lines.first else { return [] }
            // 把 key 接到首行：`    "sn": {` / `    "metrics": [`
            let firstContent = String(first.drop(while: { $0 == " " }))
            var merged = ["\(keyPrefix)\(firstContent)"]
            merged.append(contentsOf: lines.dropFirst())
            if comma, var last = merged.popLast() {
                // 注释在行尾时，逗号插在注释前
                if let range = last.range(of: "  // ") {
                    last.insert(",", at: range.lowerBound)
                    merged.append(last)
                } else {
                    merged.append(last + ",")
                }
            }
            return merged
        }
        
        let literal = scalarLiteral(value)
        let line = keyPrefix + literal + (comma ? "," : "")
        return [annotated(line, comment)]
    }
    
    private static func commentForValue(_ value: Any) -> String {
        if value is [String: Any] {
            return "object"
        }
        if let array = value as? [Any] {
            return "array(\(array.count))"
        }
        return typeName(of: value)
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
    
    private static func scalarLiteral(_ value: Any) -> String {
        switch value {
        case is NSNull:
            return "null"
        case let string as String:
            return "\"\(escapeString(string))\""
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        default:
            return "null"
        }
    }
    
    private static func escapeString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
    
    private static func annotated(_ line: String, _ comment: String?) -> String {
        guard let comment, comment.isEmpty == false else { return line }
        let trimmed = line
        if trimmed.count >= commentColumn {
            return "\(trimmed)  // \(comment)"
        }
        let padding = String(repeating: " ", count: commentColumn - trimmed.count)
        return "\(trimmed)\(padding)// \(comment)"
    }
}
