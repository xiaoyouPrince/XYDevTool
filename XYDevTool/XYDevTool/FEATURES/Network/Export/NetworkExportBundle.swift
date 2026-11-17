//
//  NetworkExportBundle.swift
//  XYDevTool
//
//  统一导出包：XYDevTool-Network-时间戳/{manifest,config,mock,docs}
//

import AppKit
import Foundation

enum NetworkExportCategory: String, Codable, CaseIterable {
    case config
    case mock
    case docs
}

struct NetworkExportManifest: Codable, Equatable {
    var version: Int
    var exportedAt: String
    var categories: [String]
    var summary: NetworkExportSummary?
    
    static let currentVersion = 1
}

struct NetworkExportSummary: Codable, Equatable {
    var requestCount: Int?
    var variableCount: Int?
    var preScriptCount: Int?
    var postScriptCount: Int?
    var mockAssetCount: Int?
}

enum NetworkExportLayout {
    /// 新包：含 manifest 或 config/ 子目录
    case bundle
    /// 旧版：目录下直接放四件套 JSON
    case legacyFlatConfig
    /// 无法识别
    case unknown
}

enum NetworkExportBundle {
    static let folderPrefix = "XYDevTool-Network-"
    static let manifestFileName = "manifest.json"
    static let configDirectoryName = "config"
    static let mockDirectoryName = "mock"
    static let docsDirectoryName = "docs"
    static let mockAssetsFileName = "network_mock_assets.json"
    static let docsFileName = "api-docs.md"
    
    static let historyFileName = "network_history.json"
    static let variablesFileName = "network_variables.json"
    static let postScriptsFileName = "network_global_scripts.json"
    static let preScriptsFileName = "network_global_pre_scripts.json"
    
    // MARK: - Paths
    
    static func configDirectory(inBundle root: URL) -> URL {
        root.appendingPathComponent(configDirectoryName, isDirectory: true)
    }
    
    static func mockDirectory(inBundle root: URL) -> URL {
        root.appendingPathComponent(mockDirectoryName, isDirectory: true)
    }
    
    static func docsDirectory(inBundle root: URL) -> URL {
        root.appendingPathComponent(docsDirectoryName, isDirectory: true)
    }
    
    static func mockAssetsURL(inBundle root: URL) -> URL {
        mockDirectory(inBundle: root).appendingPathComponent(mockAssetsFileName)
    }
    
    static func docsURL(inBundle root: URL) -> URL {
        docsDirectory(inBundle: root).appendingPathComponent(docsFileName)
    }
    
    static func manifestURL(inBundle root: URL) -> URL {
        root.appendingPathComponent(manifestFileName)
    }
    
    // MARK: - Create / write
    
    /// 在父目录下创建带时间戳的导出包根目录，并预创建所选类目子目录。
    static func createBundleRoot(inParent parent: URL, categories: [NetworkExportCategory]) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = folderPrefix + formatter.string(from: Date())
        let root = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for category in categories {
            let sub: URL
            switch category {
            case .config: sub = configDirectory(inBundle: root)
            case .mock: sub = mockDirectory(inBundle: root)
            case .docs: sub = docsDirectory(inBundle: root)
            }
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        }
        return root
    }
    
    static func writeManifest(
        toBundle root: URL,
        categories: [NetworkExportCategory],
        summary: NetworkExportSummary?
    ) throws {
        let formatter = ISO8601DateFormatter()
        let manifest = NetworkExportManifest(
            version: NetworkExportManifest.currentVersion,
            exportedAt: formatter.string(from: Date()),
            categories: categories.map(\.rawValue),
            summary: summary
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL(inBundle: root), options: .atomic)
    }
    
    // MARK: - Detect / resolve
    
    static func detectLayout(at url: URL) -> NetworkExportLayout {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return .unknown
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: manifestURL(inBundle: url).path)
            || fm.fileExists(atPath: configDirectory(inBundle: url).path) {
            return .bundle
        }
        if isLegacyFlatConfigDirectory(url) {
            return .legacyFlatConfig
        }
        return .unknown
    }
    
    static func isLegacyFlatConfigDirectory(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.appendingPathComponent(historyFileName).path)
            && fm.fileExists(atPath: url.appendingPathComponent(variablesFileName).path)
            && fm.fileExists(atPath: url.appendingPathComponent(postScriptsFileName).path)
    }
    
    /// 解析配置目录：新包取 `config/`，旧扁平目录取自身。
    static func resolvedConfigDirectory(from selected: URL) -> URL? {
        switch detectLayout(at: selected) {
        case .bundle:
            let config = configDirectory(inBundle: selected)
            return FileManager.default.fileExists(atPath: config.path) ? config : nil
        case .legacyFlatConfig:
            return selected
        case .unknown:
            return nil
        }
    }
    
    /// 解析 Mock 资产文件：包内 `mock/…`、包根下同名、或直接选中的旧单文件。
    static func resolvedMockAssetsFile(from selected: URL) -> URL? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: selected.path, isDirectory: &isDir) else {
            return nil
        }
        if isDir.boolValue {
            let inMock = mockAssetsURL(inBundle: selected)
            if FileManager.default.fileExists(atPath: inMock.path) {
                return inMock
            }
            let flat = selected.appendingPathComponent(mockAssetsFileName)
            if FileManager.default.fileExists(atPath: flat.path) {
                return flat
            }
            return nil
        }
        return selected
    }
    
    // MARK: - High-level export
    
    @discardableResult
    static func exportAll(dataModel: NetworkDataModel, toParent parent: URL) throws -> URL {
        let categories: [NetworkExportCategory] = [.config, .mock, .docs]
        let root = try createBundleRoot(inParent: parent, categories: categories)
        try dataModel.exportNetworkConfigs(to: configDirectory(inBundle: root))
        try dataModel.mockController.exportAssets(to: mockAssetsURL(inBundle: root))
        let markdown = APIDocMarkdownGenerator.generate(from: dataModel.historyRoots, scope: .all)
        try markdown.write(to: docsURL(inBundle: root), atomically: true, encoding: .utf8)
        try writeManifest(
            toBundle: root,
            categories: categories,
            summary: summary(from: dataModel)
        )
        return root
    }
    
    @discardableResult
    static func exportConfigOnly(dataModel: NetworkDataModel, toParent parent: URL) throws -> URL {
        let categories: [NetworkExportCategory] = [.config]
        let root = try createBundleRoot(inParent: parent, categories: categories)
        try dataModel.exportNetworkConfigs(to: configDirectory(inBundle: root))
        try writeManifest(
            toBundle: root,
            categories: categories,
            summary: summary(from: dataModel)
        )
        return root
    }
    
    @discardableResult
    static func exportMockOnly(mock: NetworkMockController, toParent parent: URL) throws -> URL {
        let categories: [NetworkExportCategory] = [.mock]
        let root = try createBundleRoot(inParent: parent, categories: categories)
        try mock.exportAssets(to: mockAssetsURL(inBundle: root))
        try writeManifest(
            toBundle: root,
            categories: categories,
            summary: NetworkExportSummary(mockAssetCount: mock.assets.count)
        )
        return root
    }
    
    @discardableResult
    static func exportDocsOnly(markdown: String, toParent parent: URL) throws -> URL {
        let categories: [NetworkExportCategory] = [.docs]
        let root = try createBundleRoot(inParent: parent, categories: categories)
        try markdown.write(to: docsURL(inBundle: root), atomically: true, encoding: .utf8)
        try writeManifest(toBundle: root, categories: categories, summary: nil)
        return root
    }
    
    // MARK: - High-level import
    
    struct ImportResult: Equatable {
        var importedConfig: Bool
        var importedMock: Bool
        var skippedDocs: Bool
        
        var message: String {
            var parts: [String] = []
            if importedConfig { parts.append("配置（历史/变量/脚本）") }
            if importedMock { parts.append("Mock 资产") }
            if skippedDocs { parts.append("文档已跳过（仅归档）") }
            if parts.isEmpty {
                return "未找到可导入的内容"
            }
            return "已导入：" + parts.joined(separator: "、")
        }
    }
    
    /// 从导出包或旧扁平配置目录导入。docs 不回写。
    static func importBundle(from selected: URL, into dataModel: NetworkDataModel) throws -> ImportResult {
        var importedConfig = false
        var importedMock = false
        let skippedDocs: Bool
        
        if let configDir = resolvedConfigDirectory(from: selected) {
            try dataModel.importNetworkConfigs(from: configDir)
            importedConfig = true
        }
        
        if let mockFile = resolvedMockAssetsFile(from: selected) {
            try dataModel.mockController.importAssets(from: mockFile, mode: .replace, applySettings: true)
            importedMock = true
        }
        
        let docsPath = docsURL(inBundle: selected).path
        skippedDocs = FileManager.default.fileExists(atPath: docsPath)
        
        if importedConfig == false && importedMock == false {
            throw VariableResolveError(
                message: "导入失败：无法识别导出包或旧版配置目录（需要 manifest.json / config/ 或扁平 network_history.json 等）"
            )
        }
        
        return ImportResult(
            importedConfig: importedConfig,
            importedMock: importedMock,
            skippedDocs: skippedDocs
        )
    }
    
    // MARK: - Panels
    
    static func chooseParentFolder(title: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        return panel.runModal() == .OK ? panel.url : nil
    }
    
    static func chooseImportFolder(title: String = "选择导出包或配置目录", prompt: String = "导入") -> URL? {
        chooseParentFolder(title: title, prompt: prompt)
    }
    
    // MARK: - Private
    
    private static func summary(from dataModel: NetworkDataModel) -> NetworkExportSummary {
        NetworkExportSummary(
            requestCount: dataModel.historyListUI.requestCount,
            variableCount: dataModel.variables.count,
            preScriptCount: dataModel.globalPreScripts.count,
            postScriptCount: dataModel.globalPostScripts.count,
            mockAssetCount: dataModel.mockController.assets.count
        )
    }
}
