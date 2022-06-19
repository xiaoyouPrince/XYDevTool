//
//  UpgradeViewController.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/21.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

// 本来想做App内自动升级，发现自己进程要杀死自己再启动，做不了
// 现在采用一个曲线救国的办法，让用户自己操作一下

// 自动升级
// https://www.hardcode.today/macos-app-zi-dong-sheng-ji-shi-xian.html
// 制作 dmg
// https://baijiahao.baidu.com/s?id=1696525814154677320&wfr=spider&for=pc

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
        
        let url = versionInfo?.app_zip_url().absoluteString ?? ""
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = fmt.string(from: Date())
        
        let updateSH = """
        
        #!/bin/sh

        # feature: 自动更新脚本
        # date：\(date)
        # auther： xiaoyou

        S_PATH="\(url)"

        # download
        type wget >> /dev/null
        if [[ $? != 0 ]]; then
            echo "检测到设备缺少相关下载工具，请手动下载"
            open $S_PATH
        fi
        
        wget $S_PATH
        tar xf XYDevTool.zip
        rm XYDevTool.zip

        # quit old
        ps aux | grep "XYDevTool.app" > pids

        sed -i "" '/grep/d' pids
        sed -i "" '/autoupdate/d' pids
        for pid in `awk '{print $2}' pids`; do
            kill "$pid"
        done

        rm pids

        # copy history
        # /Applications/XYDevTool.app/Contents/Resources/history.json
        cp /Applications/XYDevTool.app/Contents/Resources/history.json XYDevTool.app/Contents/Resources/

        rm -rf /Applications/XYDevTool.app

        # copy new app
        # Desktop/XYDevToolApp/XYDevTool.app
        mv XYDevTool.app /Applications/XYDevTool.app

        # run new
        open /Applications/XYDevTool.app
        
        # clear
        rm -rf \(Bundle.main.resourcePath!.appending("/autoupdate.sh"))
        
        """
        
        do {
            try (updateSH as NSString).write(toFile: Bundle.main.resourcePath!.appending("/autoupdate.sh"), atomically: true, encoding: String.Encoding.utf8.rawValue)
        } catch {
            assert(false)
            showAlert(msg: "下载失败，重试/尝试手动更新")
            return
        }
        
        showAlert(msg: "打开终端执行以下代码\n sh /Applications/XYDevTool.app/Contents/Resources/autoupdate.sh \n")
        
//        downLoad(url: versionInfo!.app_zip_url()) { success, downLoadPath in
//            print(success, "hhhhhhh")
//            if let path = downLoadPath {
////                self.doWithProcess(path)
//                self.updateToNewVersion(at: URL(fileURLWithPath: path))
////                self.updateToNewVersion(at: URL(fileURLWithPath: "\(Bundle.main.resourcePath!.appending("/XYDevTool.dmg"))"))
//            }else{
//                showAlert(msg: "下载失败，重试/尝试手动更新")
//            }
//        }
    }
    
    @IBAction func upgradeBtnAction(_ sender: NSButton) {
        if let htmlURL = versionInfo?.html_url,
            let url =  URL(string: htmlURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    
//    func doWithProcess(_ path: String){
//
//        let cmd = "/bin/sh autoupdate.sh \(path)"
////        var cmd = "/bin/sh autoupdate.sh"
//
//        var components = cmd.components(separatedBy: .whitespaces)
//
//        let task = Process()
//        task.launchPath = components[0]
//        components.remove(at: 0)
//        task.arguments = components
//        if let path = Bundle.main.resourcePath{
//            task.currentDirectoryPath = path
//        }
//
//        let outputPipe = Pipe()
//        task.standardOutput = outputPipe
//        task.standardError = outputPipe
//        let readHandle = outputPipe.fileHandleForReading
//
//        task.launch()
////        task.waitUntilExit()
//        task.resume()
//
//        let outputData = readHandle.readDataToEndOfFile()
//        let outputString = String(data: outputData, encoding: .utf8)
//
//        print("outputString -- ",outputString)
//
//        let exitStr = String(format: "Exit status: %d", task.terminationStatus)
//
//        print("exitStr -- ",exitStr)
//
//
//    }
    
//    func downLoad(url: URL, completed: @escaping (Bool, String?)->()) {
//
//        let config = URLSessionConfiguration.default
//        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
//
//        session.downloadTask(with: url) { theUrl, response, error in
//            if (error != nil) {
//                print(error)
//                completed(false,nil)
//            }else{
//                print(response, theUrl)
//                // 放到指定地点
//
//                let targetURL = URL(fileURLWithPath: Bundle.main.resourcePath!.appending("/XYDevTool.dmg"))
//                do {
//                    try FileManager.default.moveItem(at: theUrl!, to:targetURL )
//                }catch{
//                    print("出现异常-- \(error)")
//                }
//
//                completed(true, targetURL.absoluteString)
//            }
//        }.resume()
//    }
    
    
    
//    func updateToNewVersion(at url:URL) {
//        let task = Process()
//        if #available(macOS 10.13, *) {
//            task.executableURL = URL(fileURLWithPath: "/bin/sh")
//        } else {
//            task.launchPath = "/bin/sh"
//        }
//        let mountPoint = NSTemporaryDirectory().appending("\(arc4random())/")
//        if !FileManager.default.fileExists(atPath: mountPoint) {
//            do {
//                try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                assert(false)
//                return
//            }
//        }
//        let shellScript = String(format: "/usr/bin/hdiutil attach %@ -nobrowse -mountpoint %@", url.path.replacingOccurrences(of: " ", with: "\\ "), mountPoint)
//        task.arguments = ["-c", shellScript]
//        task.launch()
//        task.waitUntilExit()
//        if task.terminationStatus  == 0 {
//            let enumer = FileManager.default.enumerator(atPath: mountPoint)
//            while let fileName = enumer?.nextObject() as? String {
//                if fileName.hasSuffix(".app") {
//                    let newVersionAppPath = mountPoint.appending(fileName)
//                    if let currentRuningAppPath = NSRunningApplication.current.bundleURL?.path {
//                        let pid = ProcessInfo.processInfo.processIdentifier
//                        // remove download from website flag, avoid popup warning window
//                        let removeFlag = "/usr/bin/xattr -d -r com.apple.quarantine \"\(currentRuningAppPath)\""
//
//                        let script =
//                            "while /bin/kill -0 \(pid) >&/dev/null; do /bin/sleep 0.1; done; rm -fr \"\(currentRuningAppPath)\" && cp -r \"\(newVersionAppPath)\" \"\(currentRuningAppPath)\" && \(removeFlag); /usr/bin/open \"\(currentRuningAppPath)\"; /usr/bin/hdiutil detach \(mountPoint) &"
//                        let task = Process()
//                        if #available(macOS 10.13, *) {
//                            task.executableURL = URL(fileURLWithPath: "/bin/sh")
//                        } else {
//                            task.launchPath = "/bin/sh"
//                        }
//                        task.arguments = ["-c", script]
//                        task.launch()
//                        NSApp.terminate(nil)
//                    }
//                }
//            }
//        }
//        Process.launchedProcess(launchPath: "/usr/bin/hdiutil", arguments: ["detach", mountPoint])
//    }
}

//extension UpgradeViewController: URLSessionDownloadDelegate {
//
//    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
//        showAlert(msg: "下载完成")
//    }
//
//    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){
//        print("已经下载- \(bytesWritten)/\(totalBytesExpectedToWrite)")
//    }
//
//
//    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64){
//
//    }
//
//
//}



