//
//  HelpTopic.swift
//  XYDevTool
//

import Foundation

enum HelpTopic: String, CaseIterable, Identifiable, Hashable {
    case overview
    case gettingStarted
    case jsonFormatter
    case json2Model
    case appIcon
    case networkTool
    case customServer
    case imageInspector
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .overview: return "软件说明"
        case .gettingStarted: return "快速开始"
        case .jsonFormatter: return "JSON 格式化"
        case .json2Model: return "JSON 转 Model"
        case .appIcon: return "AppIcon 生成器"
        case .networkTool: return "网络请求工具"
        case .customServer: return "自定义服务器"
        case .imageInspector: return "图片查看器"
        }
    }
    
    var markdownFileName: String {
        switch self {
        case .overview: return "overview"
        case .gettingStarted: return "getting-started"
        case .jsonFormatter: return "json-formatter"
        case .json2Model: return "json2model"
        case .appIcon: return "app-icon"
        case .networkTool: return "network-tool"
        case .customServer: return "custom-server"
        case .imageInspector: return "image-inspector"
        }
    }
    
    var menuTitle: String? {
        switch self {
        case .overview, .gettingStarted, .networkTool: return title
        default: return nil
        }
    }
}
