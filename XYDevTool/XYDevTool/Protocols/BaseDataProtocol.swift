//
//  BaseDataProtocol.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/12/25.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Foundation

protocol BaseDataProtocol {
    
    /// 存储请求记录的路径
    var requestRecordPath: String { get }
    var history_path: String { get }
    /// App代理
    var appDelegate: AppDelegate { get }
}

extension BaseDataProtocol {
    
    var requestRecordPath: String {
        return Bundle.main.resourcePath! + "/history.json"
    }
    
    var history_path: String {
        requestRecordPath
    }

    var appDelegate: AppDelegate {
        return NSApplication.shared.delegate as! AppDelegate
    }
}
