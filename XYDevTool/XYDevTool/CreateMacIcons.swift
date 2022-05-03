//
//  CreateMacIcons.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/1.
//

import Cocoa
//import ImageIO
import SnapKit

class CreateMacIcons: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        // 在这里写一个提示文件，将具体的操作方法以及 sh 写到App中，方便以后查看即可
        
    }
    
    func doWithPrivilegedTask(){
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
        
        let cmd = "/bin/sh mac_icon.sh /im.png"
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
    }
    
    func doWithProcess(){
        //        let cmd = "/bin/sh script.sh"
        let cmd = "/bin/sh mac_icon.sh ~/Desktop/im.png"
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
    }
    
    
    
   
    

    
}
