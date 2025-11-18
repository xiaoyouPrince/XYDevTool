//
//  JSONFormatterFunctionsView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/9/30.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

struct JSONFormatterFunctionsView: View {
    @Binding var text: String
    @State var status: String = ""
    
    let funcsArray: [String] = [
        "JSON 格式化", 
        "压缩",
        "转义",
        "去除转义",
        "汉字转 Unicode",
        "Unicode 转汉字",
        "随机生成 JSON 串",
        "URL编吗(通用)",
        "URL编吗(严格)",
        "URL解码",
    ]
    
    var body: some View {
        VStack {
            ForEach(0..<funcsArray.count, id: \.self) { idx in
                Button {
                    makeFunc(with: idx)
                } label: {
                    ZStack {
                        Text(funcsArray[idx])
                            .padding(.vertical, 5)
                            .frame(width: 150)
                    }
                }
            }
            
            Text(status)
                .font(.system(size: 14))
                .fontWeight(.regular)
                .foregroundColor(.red)
                .frame(width: 150, alignment: .leading)
                .padding(.top, 10)
            Spacer()
        }.padding(.top, 20)
    }
}

extension JSONFormatterFunctionsView {
    
    func makeFunc(with idx: Int) {
        let funcName: String = funcsArray[idx]
        switch idx {
        case 0: okClick(funcName)
        case 1: compressionAction(funcName)
        case 2: addEscape(funcName)
        case 3: removeEscape(funcName)
        case 4: Chinese2Unicode(funcName)
        case 5: Unicode2Chinese(funcName)
        case 6: createRandomJSON(funcName)
        case 7: stringURLEncode(funcName)
        case 8: stringURLEncode2(funcName)
        case 9: stringURLDecode(funcName)
        default:
            break
        }
    }
    
    func okClick(_ funcName: String) {
        
        // 去掉空格和换行先
        let str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 字符串无法直接转换成json egg:"{\n    \"code\": 200 }
        if str.first == "\"" { // 字符串开头，不支持格式化
            status = "纯字符串无法转换"
            return
        }
        
        if let data = str.data(using: .utf8) {
            do {
                let dict =  try JSONSerialization.jsonObject(with: (data as Data), options: .fragmentsAllowed)
                let preData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                let resultStr = String(data: preData, encoding: .utf8)
                
                setResult(string: resultStr!, desc: funcName)
            }catch{
                print(error)
                let err = error as NSError
                status = err.userInfo.description
            }
        }
    }
    
    
    func compressionAction(_ funcName: String) {
        
        let str = text.components(separatedBy: CharacterSet.whitespacesAndNewlines).joined(separator: "")
        
        setResult(string: str, desc: funcName)
    }
    
    
    func addEscape(_ funcName: String) {
        let result = text.addEscape()
        setResult(string: result, desc: funcName)
    }
    
    
    func removeEscape(_ funcName: String) {
        let result = text.removeEscape()
        setResult(string: result, desc: funcName)
    }
    
    
    func Chinese2Unicode(_ funcName: String) {
        
        let result = text.chinese2Unicode()
        setResult(string: result, desc: funcName)
    }
    
    func Unicode2Chinese(_ funcName: String) {
        
        let result = text.unicode2Chinese()
        setResult(string: result, desc: funcName)
    }
    
    func createRandomJSON(_ funcName: String) {
        
        let result = getRandomJSON(maxLayer: 8, maxElementsPerLayer: 8)
        setResult(string: result, desc: funcName)
    }
    
    func stringURLEncode(_ funcName: String) {
        
        let result = text.urlEncoded
        setResult(string: result, desc: funcName)
    }
    
    func stringURLEncode2(_ funcName: String) {
        
        let result = text.urlQueryValueEncoded
        setResult(string: result, desc: funcName)
    }
    
    func stringURLDecode(_ funcName: String) {
        
        let result = text.urlDecoded
        setResult(string: result, desc: funcName)
    }
    
    func setResult(string: String, desc: String) {
        text = string
        spaceKeyDownAndDelete()
        status = desc + "完成"
    }
}



