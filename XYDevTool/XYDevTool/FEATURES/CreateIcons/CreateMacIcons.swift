//
//  CreateMacIcons.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/1.
//

/**
 总结：
 1. 要操作系统内的文件，必须要关闭沙盒功能(.entiltlements). 且要访问的资源地址是必须是决定路径，相对路径访问不到
 2. 此功能尝试了三种做法，兜兜转转回到最初，因为最初的想法一直是本心的想法，学习成本低，后面的使用纯mac编程想法都是无奈之举(1. 使用脚本，2 使用超级管理权限脚本，3. 纯原生编程，通过编程的方式处理图片，并生成内容放到指定Path。 最终经过多次调试和查资料发现方案一的可行性。)
 3. app 内的地址： Bundle.main.resourcePath 即当前资源所在地址
 */


import Cocoa
import SnapKit

class CreateMacIcons: NSViewController {
    
    let ICON_NAME: String = "icon.png"
    
    enum IconType: String {
        case macOS, iOS
    }
    
    struct IconInfo {
        var type: IconType = .macOS
        var path: String?
    }

    @IBOutlet weak var img: NSImageView!
    @IBOutlet weak var popBtn: NSPopUpButton!
    @IBOutlet weak var targetPath: NSPathControl!
    
    @IBOutlet weak var statusLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        img.isEditable = true
        statusLabel.stringValue = ""
        statusLabel.textColor = NSColor.red
        
        self.view.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 343, height: 558))
        }
        
        popBtn.removeAllItems()
        popBtn.addItem(withTitle: "macOS")
        popBtn.addItem(withTitle: "iOS")
        
        targetPath.isEditable = true
        targetPath.pathStyle = .popUp
        targetPath.url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        
    }
    
    @IBAction func okBtnClick(_ sender: Any) {
        
        // 1. 指定源文件，放到本地路径来. 需要注意的是所有 sh 操作都在本地资源路径下
        // 2. 类型 macOS/iOS
        // 3. 指定生成路径
        
        if img.image == NSImage(named: "icon_bg") {
            showAlert(msg: "请拖入标准尺寸Icon图")
            return;
        }

        let fmgr = FileManager.default
        if fmgr.createFile(atPath: Bundle.main.resourcePath! + "/icon.png", contents: img.image!.tiffRepresentation, attributes: nil) {
            print("创建文件成功")
        }else {
            showAlert(msg: "图片异常，创建失败")
        }
        
        let type = popBtn.title
        var pathFromTarget = targetPath.pathItems.reduce("") { partialResult, item in
            return partialResult + "/" + item.title
        } // /MacBook Pro/Untitled/Users/quxiaoyou/Desktop
        let path = pathFromTarget.replacingOccurrences(of: "/MacBook Pro/Untitled", with: "")
        
//        doWithPrivilegedTask(image: NSImage())
        
        let info = IconInfo(type: IconType(rawValue: type)!, path: path)
        doWithProcess(info)
        
        return;
        
        let image = img.image
//        doWithPrivilegedTask(image: image!)
        
//        NSImage
        
        
//        let fmgr = FileManager()
//        let contents = try? fmgr.contentsOfDirectory(atPath: "/Users/quxiaoyou/Desktop")
//        print(contents)
//
//
//        if fmgr.createFile(atPath: "/Users/quxiaoyou/Desktop/New", contents: image?.tiffRepresentation, attributes: nil) {
//            print("创建文件成功")
//        }else {
//
//        }
//
    }
    
    
    func doWithPrivilegedTask(_ info: IconInfo){
        // 因为 系统限制，这里卡死了
        // 1. 图片资源必须放入到 Assets.xcassets 中，经编译就变成了 assets.car 文件文件了，无法打开。。 如果不放在此文件中需要开发证书
        // 2. 无法直接访问系统内的资源
        
        // 3. 技术不精，决定放弃
        //
        // 接下来，在这里写一个提示文件，将具体的操作方法以及 sh 写到App中，方便以后查看即可
        
//        let iv = NSImageView(image: NSImage(contentsOfFile: "im.png")!)
        let iv = NSImageView(image: NSImage(named: "im")!)
        view.addSubview(iv)
        iv.frame = view.bounds
                
        
        
//        let path = Bundle.main.path(forResource: "Assets", ofType: "xcassets")!
//        let path = FileManager().currentDirectoryPath

        let path = Bundle.main.resourcePath
        print(path)
        
        let cmd = "/bin/sh mac_icon.sh /Users/quxiaoyou/Desktop/im.png"
        var components = cmd.components(separatedBy: .whitespaces)
        
        let privilegedTask = STPrivilegedTask()
        privilegedTask.launchPath = components[0]
        components.remove(at: 0)
        privilegedTask.arguments = components
        if let path = Bundle.main.resourcePath{
            privilegedTask.currentDirectoryPath = path
        }
        
        let err = privilegedTask.launch()
        if err != errAuthorizationSuccess {
            if err == errAuthorizationCanceled {
                print("user canceled ...")
                return
            }else
            {
                print("something went wrong", Int(err))
                //// For error codes, see http://www.opensource.apple.com/source/libsecurity_authorization/libsecurity_authorization-36329/lib/Authorization.h
                return
            }
        }
        
        privilegedTask.waitUntilExit()
        
        let readHandle = privilegedTask.outputFileHandle
        
        let outputData = readHandle?.readDataToEndOfFile()
        let outputString = String(data: outputData!, encoding: .utf8)
        
        print("outputString -- ",outputString)
        
        let exitStr = String(format: "Exit status: %d", privilegedTask.terminationStatus)
        
        print("exitStr -- ",exitStr)
        
        showResult(path: info.path!, code: privilegedTask.terminationStatus)
    }
    
    func doWithProcess(_ info: IconInfo){
        // let cmd = "/bin/sh script.sh"
        // let cmd = "/bin/sh mac_icon.sh /Users/quxiaoyou/Desktop/im.png"
        // let cmd = "/bin/sh mac_icon.sh icon.png"
        
        var cmd = "/bin/sh "
        
        switch info.type {
        case .macOS:
            cmd.append("mac_icon.sh \(ICON_NAME) ")
        case .iOS:
            
            cmd.append("ios_icon.sh \(ICON_NAME) ")
        }
        
        cmd.append(info.path!)
        
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
        task.waitUntilExit()
        
        let outputData = readHandle.readDataToEndOfFile()
        let outputString = String(data: outputData, encoding: .utf8)
        
        print("outputString -- ",outputString)
        
        let exitStr = String(format: "Exit status: %d", task.terminationStatus)
        
        print("exitStr -- ",exitStr)
        
        showResult(path: info.path!, code: task.terminationStatus)
    }
    
    func showResult(path: String, code: Int32) {
        let filePath = path + "/AppIcon.appiconset"
        if code != 0 {
            // 有可能是系统路径，没有权限，不做处理了
            statusLabel.stringValue = "请检查 \(filePath) 已存在, 为避免覆盖操作导致文件丢失，请先手动处理已有文件"
            showAlert(msg: "异常")
        }else{
            statusLabel.stringValue = "操作完成，存储地址 \(filePath)"
            showAlert(msg: "成功")
        }
    }
}
