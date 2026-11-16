//
//  MockResponseAssembler.swift
//  XYDevTool
//

import Foundation

enum MockResponseAssembler {
    private static let metaKeys: Set<String> = [
        "_statusCode",
        "_headers",
        "_mimeType"
    ]
    
    static func assemble(from responseText: String) -> MockAssembledResponse {
        let trimmed = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return MockAssembledResponse(
                statusCode: 200,
                contentType: "text/plain; charset=utf-8",
                body: Data(trimmed.utf8)
            )
        }
        
        guard let object = json as? [String: Any] else {
            let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data(trimmed.utf8)
            return MockAssembledResponse(
                statusCode: 200,
                contentType: "application/json",
                body: body
            )
        }
        
        let statusCode = parseStatusCode(object["_statusCode"])
        let mimeType = object["_mimeType"] as? String
        
        if let text = object["_text"] as? String,
           businessKeys(in: object).isEmpty {
            let contentType = contentTypeForMime(mimeType, fallback: "text/plain; charset=utf-8")
            return MockAssembledResponse(
                statusCode: statusCode,
                contentType: contentType,
                body: Data(text.utf8)
            )
        }
        
        if let array = object["_jsonArray"],
           businessKeys(in: object).isEmpty {
            let body = (try? JSONSerialization.data(withJSONObject: array)) ?? Data("[]".utf8)
            return MockAssembledResponse(
                statusCode: statusCode,
                contentType: "application/json",
                body: body
            )
        }
        
        if let base64 = object["_base64"] as? String,
           businessKeys(in: object).isEmpty {
            let wrapped: [String: Any] = ["_base64": base64]
            let body = (try? JSONSerialization.data(withJSONObject: wrapped)) ?? Data("{}".utf8)
            return MockAssembledResponse(
                statusCode: statusCode,
                contentType: "application/json",
                body: body
            )
        }
        
        var business: [String: Any] = [:]
        for (key, value) in object where metaKeys.contains(key) == false {
            if key == "_text" || key == "_jsonArray" || key == "_base64" {
                continue
            }
            business[key] = value
        }
        
        // Keep special body keys only when mixed with business fields.
        if business.isEmpty {
            if let text = object["_text"] as? String {
                return MockAssembledResponse(
                    statusCode: statusCode,
                    contentType: contentTypeForMime(mimeType, fallback: "text/plain; charset=utf-8"),
                    body: Data(text.utf8)
                )
            }
            if let array = object["_jsonArray"] {
                let body = (try? JSONSerialization.data(withJSONObject: array)) ?? Data("[]".utf8)
                return MockAssembledResponse(
                    statusCode: statusCode,
                    contentType: "application/json",
                    body: body
                )
            }
        }
        
        let body = (try? JSONSerialization.data(withJSONObject: business)) ?? Data("{}".utf8)
        return MockAssembledResponse(
            statusCode: statusCode,
            contentType: "application/json",
            body: body
        )
    }
    
    private static func businessKeys(in object: [String: Any]) -> [String] {
        object.keys.filter { key in
            metaKeys.contains(key) == false
                && key != "_text"
                && key != "_jsonArray"
                && key != "_base64"
        }
    }
    
    private static func parseStatusCode(_ value: Any?) -> Int {
        if let intValue = value as? Int, (100...599).contains(intValue) {
            return intValue
        }
        if let number = value as? NSNumber {
            let intValue = number.intValue
            if (100...599).contains(intValue) {
                return intValue
            }
        }
        if let string = value as? String, let intValue = Int(string), (100...599).contains(intValue) {
            return intValue
        }
        return 200
    }
    
    private static func contentTypeForMime(_ mimeType: String?, fallback: String) -> String {
        guard let mimeType, mimeType.isEmpty == false else { return fallback }
        return mimeType
    }
}
