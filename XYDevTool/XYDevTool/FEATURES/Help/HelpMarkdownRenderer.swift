//
//  HelpMarkdownRenderer.swift
//  XYDevTool
//

import Foundation

enum HelpMarkdownRenderer {
    
    static func htmlDocument(body markdown: String, title: String) -> String {
        let escapedTitle = escapeHTML(title)
        let bodyHTML = htmlBody(from: markdown)
        return """
        <!DOCTYPE html>
        <html lang="zh-Hans">
        <head>
            <meta charset="utf-8">
            <meta name="color-scheme" content="light dark">
            <title>\(escapedTitle)</title>
            <style>
                :root {
                    color-scheme: light dark;
                    --text: #1d1d1f;
                    --secondary: #6e6e73;
                    --border: #d2d2d7;
                    --surface: #f5f5f7;
                    --link: #0066cc;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --text: #f5f5f7;
                        --secondary: #a1a1a6;
                        --border: #48484a;
                        --surface: #2c2c2e;
                        --link: #64d2ff;
                    }
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif;
                    font-size: 14px;
                    line-height: 1.65;
                    color: var(--text);
                    margin: 0;
                    padding: 4px 8px 24px;
                    word-wrap: break-word;
                }
                h1 { font-size: 1.75rem; font-weight: 700; margin: 0.2em 0 0.8em; line-height: 1.25; }
                h2 {
                    font-size: 1.3rem; font-weight: 650; margin: 1.4em 0 0.55em;
                    padding-bottom: 0.3em; border-bottom: 1px solid var(--border);
                }
                h3 { font-size: 1.08rem; font-weight: 600; margin: 1.1em 0 0.45em; }
                p { margin: 0.65em 0; }
                ul, ol { margin: 0.55em 0 0.85em; padding-left: 1.45em; }
                li { margin: 0.28em 0; }
                li > ul, li > ol { margin-top: 0.2em; margin-bottom: 0.2em; }
                table {
                    width: 100%; border-collapse: collapse; margin: 0.85em 0 1.1em;
                    font-size: 0.95rem;
                }
                th, td {
                    border: 1px solid var(--border);
                    padding: 8px 12px;
                    text-align: left;
                    vertical-align: top;
                }
                th { background: var(--surface); font-weight: 600; }
                code {
                    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
                    font-size: 0.9em;
                    background: var(--surface);
                    padding: 2px 6px;
                    border-radius: 4px;
                }
                pre {
                    background: var(--surface);
                    padding: 12px 14px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 0.85em 0;
                }
                pre code { background: none; padding: 0; font-size: 0.88em; }
                a { color: var(--link); text-decoration: none; }
                a:hover { text-decoration: underline; }
                hr { border: none; border-top: 1px solid var(--border); margin: 1.4em 0; }
                strong { font-weight: 650; }
            </style>
        </head>
        <body>\(bodyHTML)</body>
        </html>
        """
    }
    
    // MARK: - Parser
    
    private static func htmlBody(from markdown: String) -> String {
        let blocks = parseBlocks(markdown)
        return blocks.map(renderBlock).joined(separator: "\n")
    }
    
    private enum Block {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case list(ordered: Bool, items: [String])
        case table(headers: [String], rows: [[String]])
        case code(text: String)
        case thematicBreak
    }
    
    private static func parseBlocks(_ markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [Block] = []
        var index = 0
        
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                index += 1
                continue
            }
            
            if trimmed.hasPrefix("```") {
                index += 1
                var codeLines: [String] = []
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.code(text: codeLines.joined(separator: "\n")))
                continue
            }
            
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.thematicBreak)
                index += 1
                continue
            }
            
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 3), text: text))
                index += 1
                continue
            }
            
            if isTableRow(trimmed), index + 1 < lines.count, isTableSeparator(lines[index + 1]) {
                let headers = parseTableCells(trimmed)
                index += 2
                var rows: [[String]] = []
                while index < lines.count, isTableRow(lines[index].trimmingCharacters(in: .whitespaces)) {
                    rows.append(parseTableCells(lines[index].trimmingCharacters(in: .whitespaces)))
                    index += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }
            
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var items: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    if current.hasPrefix("- ") || current.hasPrefix("* ") {
                        items.append(String(current.dropFirst(2)))
                        index += 1
                    } else {
                        break
                    }
                }
                blocks.append(.list(ordered: false, items: items))
                continue
            }
            
            if let _ = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                var items: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    if let range = current.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        items.append(String(current[range.upperBound...]))
                        index += 1
                    } else {
                        break
                    }
                }
                blocks.append(.list(ordered: true, items: items))
                continue
            }
            
            var paragraphLines: [String] = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("```")
                    || next.hasPrefix("- ") || next.hasPrefix("* ")
                    || isTableRow(next) {
                    break
                }
                if next.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            blocks.append(.paragraph(text: paragraphLines.joined(separator: " ")))
        }
        
        return blocks
    }
    
    private static func renderBlock(_ block: Block) -> String {
        switch block {
        case .heading(let level, let text):
            return "<h\(level)>\(inlineHTML(text))</h\(level)>"
        case .paragraph(let text):
            return "<p>\(inlineHTML(text))</p>"
        case .list(let ordered, let items):
            let tag = ordered ? "ol" : "ul"
            let lis = items.map { "<li>\(inlineHTML($0))</li>" }.joined()
            return "<\(tag)>\(lis)</\(tag)>"
        case .table(let headers, let rows):
            let ths = headers.map { "<th>\(inlineHTML($0))</th>" }.joined()
            let trs = rows.map { row in
                let tds = row.map { "<td>\(inlineHTML($0))</td>" }.joined()
                return "<tr>\(tds)</tr>"
            }.joined()
            return "<table><thead><tr>\(ths)</tr></thead><tbody>\(trs)</tbody></table>"
        case .code(let text):
            return "<pre><code>\(escapeHTML(text))</code></pre>"
        case .thematicBreak:
            return "<hr>"
        }
    }
    
    private static func inlineHTML(_ text: String) -> String {
        var result = escapeHTML(text)
        
        // links [title](url)
        result = replaceRegex(in: result, pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) { match in
            let title = escapeHTML(match[1])
            let url = escapeHTML(match[2])
            return "<a href=\"\(url)\">\(title)</a>"
        }
        
        // inline code `code`
        result = replaceRegex(in: result, pattern: #"`([^`]+)`"#) { match in
            return "<code>\(match[1])</code>"
        }
        
        // bold **text**
        result = replaceRegex(in: result, pattern: #"\*\*([^*]+)\*\*"#) { match in
            return "<strong>\(match[1])</strong>"
        }
        
        return result
    }
    
    private static func isTableRow(_ line: String) -> Bool {
        line.contains("|") && line.filter({ $0 != "|" && !$0.isWhitespace && $0 != "-" && $0 != ":" }).isEmpty == false
    }
    
    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("|") && trimmed.replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private static func parseTableCells(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
    }
    
    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
    
    private static func replaceRegex(in text: String, pattern: String, transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var result = text
        let matches = regex.matches(in: text, range: nsRange).reversed()
        for match in matches {
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                guard let range = Range(match.range(at: i), in: text) else { continue }
                groups.append(String(text[range]))
            }
            guard let wholeRange = Range(match.range(at: 0), in: result) else { continue }
            result.replaceSubrange(wholeRange, with: transform(groups))
        }
        return result
    }
}
