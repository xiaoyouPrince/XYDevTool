//
//  UpgradeViewController.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/21.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Cocoa

class UpgradeViewController: NSViewController {
    @IBOutlet weak var verstionLab: NSTextField!
    @IBOutlet weak var currentVertionLab: NSTextField!
    @IBOutlet weak var descLab: NSTextField!
    @IBOutlet weak var upgradeBtn: NSButton!
    
    var versionInfo: Version?
    var currentVer: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "版本更新"
        verstionLab.stringValue = "最新版本: \(versionInfo?.tag_name ?? "unknown")"
        currentVertionLab.stringValue = "当前版本: \(currentVer ?? "unknown")"
        descLab.stringValue = "更新说明:\n" + "\(versionInfo?.body ?? "unknown")"
        upgradeBtn.title = "更新"
    }
    
    
    @IBAction func oneKeyUpgrade(_ sender: Any) {
        
        downLoad(url: versionInfo!.app_zip_url()) { success, downLoadPath in
            print(success, "hhhhhhh")
            if let path = downLoadPath {
                self.doWithProcess(path)
            }else{
                showAlert(msg: "下载失败，重试/尝试手动更新")
            }
        }
    }
    
    @IBAction func upgradeBtnAction(_ sender: NSButton) {
        if let htmlURL = versionInfo?.html_url,
            let url =  URL(string: htmlURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    
    func doWithProcess(_ path: String){
        
        let cmd = "/bin/sh autoupdate.sh \(path)"
//        var cmd = "/bin/sh autoupdate.sh"
        
        var components = cmd.components(separatedBy: .whitespaces)
        
        let task = Process()
        task.launchPath = components[0]
        components.remove(at: 0)
        task.arguments = components
        if let path = Bundle.main.resourcePath{
            task.currentDirectoryPath = path
        }
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe
        let readHandle = outputPipe.fileHandleForReading
        
        task.launch()
//        task.waitUntilExit()
        task.resume()
        
        let outputData = readHandle.readDataToEndOfFile()
        let outputString = String(data: outputData, encoding: .utf8)
        
        print("outputString -- ",outputString)
        
        let exitStr = String(format: "Exit status: %d", task.terminationStatus)
        
        print("exitStr -- ",exitStr)
        
        
    }
    
    func downLoad(url: URL, completed: @escaping (Bool, String?)->()) {
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        
        session.downloadTask(with: url) { theUrl, response, error in
            if (error != nil) {
                print(error)
                completed(false,nil)
            }else{
                print(response, theUrl)
                // 放到指定地点
            
                let targetURL = URL(fileURLWithPath: Bundle.main.resourcePath!.appending("/XYDevTool.zip"))
                do {
                    try FileManager.default.moveItem(at: theUrl!, to:targetURL )
                }catch{
                    print("出现异常-- \(error)")
                }
                
                completed(true, "XYDevTool.zip")
            }
        }.resume()
    }
}

extension UpgradeViewController: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        showAlert(msg: "下载完成")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){
        print("已经下载- \(bytesWritten)/\(totalBytesExpectedToWrite)")
    }

    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64){
        
    }
    
    
}



