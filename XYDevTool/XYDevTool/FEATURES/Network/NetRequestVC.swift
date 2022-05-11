//
//  NetRequestVC.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/10.
//

// 使用 NSTableView https://www.jianshu.com/p/09f1ea8fb7bf

import Cocoa

class NetRequestVC: NSViewController {
    
    
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var methodBtn: NSPopUpButton!
    @IBOutlet weak var urlTF: NSTextField!
    @IBOutlet weak var sendBtn: NSButton!
    
    @IBOutlet var headerTCV: NSTextView!
    @IBOutlet var bodyTV: NSTextView!
    @IBOutlet var resultTV: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        tableView.delegate = self
        tableView.dataSource = self
        
        
    }
    
    func getUrl() -> URL? {
        var string = urlTF.stringValue
        if string.isEmpty {
            return nil
        }
        string = string.trimmingCharacters(in: .whitespacesAndNewlines)
        string = string.lowercased()
        
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            return URL(string: string)
        }else{
            return URL(string: "http://" + string)
        }
    }
    
    func getDefaultHeaders(with url: URL) -> [String: String] {
        let headers: [String: String] =
        [
            "Content-Type": "application/json"
        ]
        
        return headers
    }
    
    
    @IBAction func sendBtnClick(_ sender: Any) {
        
        // url
        guard let url = getUrl() else {
            showAlert(msg: "网址有误，输入正确的网址")
            return
        }
        self.resultTV.string = "请求中，当前小🌈会转起来，因为我故意阻塞了主线程😂。。。稍等一下！"
        
        let semaphore = DispatchSemaphore (value: 0)

        let parameters = bodyTV.string
        let postData = parameters.data(using: .utf8)

        // md: 这不是 Apple 的问题就是接口的问题。
        // 下面两个创建 request 的方式必须要直接用 string 实例来创建，草。。。浪费大半天时间
        // md: 必须直接用 urlTF.stringValue 创建 URL，入参数是 上面 url.absoutString 都不行
        // 实际上都能建立链接，但是接口返回的 下面的方式就是 200，反之就是 404 找不到请求的路径。 fuck！！！
        
        //var request = URLRequest(url: URL(string: "http://b-officialaccountresume-officialaccountresume.zpidc.com/adminService/sendRecommendActiveStaffEvent")!,timeoutInterval: Double.infinity)
        var request = URLRequest(url: URL(string: urlTF.stringValue)!, timeoutInterval: Double.infinity)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpMethod = methodBtn.selectedItem?.title
        request.httpBody = postData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {

                let errMsg = String(describing: error)
                semaphore.signal()

                DispatchQueue.main.async {
                    self.resultTV.string = String(describing: error)
                }
                print(errMsg)
                return
            }

            let sucString = String(data: data, encoding: .utf8)!
            print(sucString)
            DispatchQueue.main.async {
                self.resultTV.string = sucString
            }

            semaphore.signal()
        }

        task.resume()
        semaphore.wait()
        
        return;
        
        // MARK: - 错误大概是apple问题，直接通过 URL 创建 Request 的问题。
        // url
        guard let url = getUrl() else {
            showAlert(msg: "网址有误，输入正确的网址")
            return
        }
        
        // method
        var method = NetTool.RequestType.GET
        if methodBtn.stringValue == "GET" {
            method = NetTool.RequestType.GET
        }else{
            method = NetTool.RequestType.POST
        }
        
        // headers
        var defaultHeaders: [String: String] = getDefaultHeaders(with: url)
        if let headerDict = srting2JsonObject(string: headerTCV.string) {
            // print
            print("headers - \(headerDict)")
            for (key, value) in headerDict {
                if value is String {
                    defaultHeaders[key] = value as! String
                }
            }
        }
        
        // body
        var body: [String: Any] = [:]
        if let bodyDict = srting2JsonObject(string: bodyTV.string) {
            print("bodys - \(bodyDict)")
            body = bodyDict
        }
        
        
        // 发起请求
        NetTool.request(url: url, method: method, paramters: body, headers:defaultHeaders) {[weak self] result in
            self?.resultTV.string = result.toString() ?? ""
        } failure: { errMsg in
            showAlert(msg: errMsg)
        }
        
        
//        let url = URL(string: "http://b-officialaccountresume-officialaccountresume.zpidc.com/adminService/sendRecommendActiveStaffEvent")!
        
//        let url = URL(string: "http://127.0.0.1/json")!
        

    }
    
    
}

extension NetRequestVC: NSTableViewDataSource {
  
    func numberOfRows(in tableView: NSTableView) -> Int {
        return 5 // directoryItems?.count ?? 0
    }
}

extension NetRequestVC: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let CellID = "cellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.CellID), owner: nil) as? NSTableCellView {
            
            cell.textField?.stringValue = "nihao"
            cell.layer?.backgroundColor = NSColor.red.cgColor
            cell.imageView?.image = NSImage(named: "im")
            return cell
        }
        
        return nil
      
      

//    var image: NSImage?
//    var text: String = ""
//    var cellIdentifier: String = ""
//
//    let dateFormatter = DateFormatter()
//    dateFormatter.dateStyle = .long
//    dateFormatter.timeStyle = .long
//    // 1
//    guard let item = directoryItems?[row] else {
//      return nil
//    }
//
//    // 2
//    if tableColumn == tableView.tableColumns[0] {
//      image = item.icon
//      text = item.name
//      cellIdentifier = CellIdentifiers.NameCell
//    } else if tableColumn == tableView.tableColumns[1] {
//      text = dateFormatter.string(from: item.date)
//      cellIdentifier = CellIdentifiers.DateCell
//    } else if tableColumn == tableView.tableColumns[2] {
//      text = item.isFolder ? "--" : sizeFormatter.string(fromByteCount: item.size)
//      cellIdentifier = CellIdentifiers.SizeCell
//    }
//
//    // 3
//    if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
//      cell.textField?.stringValue = text
//      cell.imageView?.image = image ?? nil
//      return cell
//    }
//    return nil
  }

}
