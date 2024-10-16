//
//  CustomServerView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/10/8.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI
import Combine

struct CustomServerView: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            /*
             1. 启动/关闭按钮.
             2. 提供一套常规接口 json / file / image / video / zip
             3. 启动前配置, 端口号(避免冲突),
             2. 支持自己设置根目录的文件夹存放位置. 需要按照文件夹规则设置文件夹
             3. 支持自定义请求路径和返回内容:「根路径:端口是服务本身生成的」
             */
            
            TerminalView()
        }
    }
}

import SwiftUI
import Combine


struct TerminalView: View {
    @StateObject private var terminal = TerminalViewModel()  // 终端 ViewModel
    @State var scrollToBottomID: UUID = UUID()
    
    var body: some View {
        VStack {
            // 显示终端输出
            TextEditor(text: $terminal.output)
                .font(.system(.body, design: .monospaced))  // 使用等宽字体
                .padding()
                .frame(minHeight: 300)  // 设置最小高度
            
            // 用户输入框
            HStack {
                TextField("Enter command", text: $terminal.input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        terminal.sendCommand()  // 当用户按下回车时发送命令
                    }
                    .padding()
                
                Button("Send") {
                    terminal.sendCommand()
                }
                .padding()
            }
            
            // 中断按钮模拟 Control + C
            Button("Interrupt (Ctrl+C)") {
                terminal.interruptProcess()  // 模拟 Ctrl+C 中断进程
            }
            .padding()
            .foregroundColor(.red)
        }
        .onAppear {
            terminal.startProcess()  // 启动终端进程
        }
        .onDisappear {
            terminal.stopProcess()  // 停止终端进程
        }
    }
}

class TerminalViewModel: ObservableObject {
    @Published var output: String = ""   // 输出内容
    @Published var input: String = ""    // 用户输入
    
    private var process: Process!
    private var outputPipe: Pipe!
    private var inputPipe: Pipe!
    private var outputHandle: FileHandle!
    
    // 启动终端进程
    func startProcess() {
        process = Process()
        process.launchPath = "/bin/bash"  // 使用 bash shell
        process.arguments = ["-i"]  // 以交互模式启动
        
        outputPipe = Pipe()
        inputPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = outputPipe  // 捕获错误输出
        process.standardInput = inputPipe   // 用于写入输入
        
        outputHandle = outputPipe.fileHandleForReading
        
        // 监听输出
        outputHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    self?.output += output  // 追加输出到 output 属性中
                }
            }
        }
        
        // 启动进程
        process.launch()
    }
    
    // 发送用户输入的命令
    func sendCommand() {
        let command = input + "\n"
        if let inputData = command.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(inputData)  // 写入命令到标准输入
        }
        input = ""  // 清空输入框
    }
    
    // 查找并杀死实际的子进程
    func interruptProcess() {
        if process.isRunning {
            // 查找子进程 PID
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "pgrep -P \(process.processIdentifier)"]  // 查找 bash 的子进程
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let pidString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = Int32(pidString) {
                // 使用 SIGKILL 杀死子进程
                kill(pid, SIGINT)
            }
        }
    }
    
    // 停止进程
    func stopProcess() {
        if process.isRunning {
            process.terminate()  // 安全地终止进程
            process.waitUntilExit()  // 等待进程完全退出
        }
    }
}





