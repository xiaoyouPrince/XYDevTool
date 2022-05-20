//
//  UpgradeUtils.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/20.
//

import Foundation

class UpgradeUtils {
    static let GITHUB_RELEASES_URL = "https://api.github.com/repos/xiaoyouPrince/XYDevTool/releases"
    
    class func newestVersion(completion:@escaping ((Version?) -> ())) {
        DispatchQueue.global().async {
            guard let infoURL = URL(string: GITHUB_RELEASES_URL),
                let infoData = try? Data(contentsOf: infoURL),
                let version = try? JSONDecoder().decode([Version].self, from: infoData) else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
            }
            
            DispatchQueue.main.async {
                completion(version.first)
            }
        }
    }
}

class Version: Codable {
    
    /** https://api.github.com/repos/xiaoyouPrince/XYDevTool/releases/66602654 */
    var url: String?
    
    /** 1.1.0 */
    var tag_name: String?
    
    /** 1.1.0 JSON 解析和 API 请求工具 */
    var name: String?
    
    /** 2022-05-11T16:21:59Z */
    var published_at: String?
    
    /** https://api.github.com/repos/xiaoyouPrince/XYDevTool/tarball/1.1.0 */
    var tarball_url: String?
    
    /** https://api.github.com/repos/xiaoyouPrince/XYDevTool/zipball/1.1.0 */
    var zipball_url: String?
    
    /** 新增 JSON 格式化功能 ... */
    var body: String?
}
