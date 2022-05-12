//
//  NetRequestVC.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/10.
//

// 使用 NSTableView https://www.jianshu.com/p/09f1ea8fb7bf

import Cocoa

class NetRequestVC: NSViewController {
    
    let history_path = Bundle.main.resourcePath! + "/history.json"
    var dataArray: [XYItem] = []
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var methodBtn: NSPopUpButton!
    @IBOutlet weak var nameTF: NSTextField!
    @IBOutlet weak var urlTF: NSTextField!
    @IBOutlet weak var sendBtn: NSButton!
    
    @IBOutlet var headerTCV: NSTextView!
    @IBOutlet var bodyTV: NSTextView!
    @IBOutlet var resultTV: NSTextView!
    @IBOutlet weak var lockBtn: NSButton!
    
    var lastSelectedRow = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        tableView.delegate = self
        tableView.dataSource = self
        
        // 读取历史数据
        
        if let data = NSData(contentsOfFile: history_path), let historys = MyObj.mapping(jsonData: data as Data) {
            dataArray = historys.item ?? []
            tableView.reloadData()
        }
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
    
    
    @IBAction func lockBtnClick(_ sender: Any) {
        if lastSelectedRow >= 0 {
            // 更新当前选中的 cell。数据并保存历史记录
            dataArray[lastSelectedRow].isLock = lockBtn.state.rawValue == 1
            updateHistory()
        }
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
        
        var request: URLRequest! = nil
        if methodBtn.selectedItem?.title == "POST" {
            request = URLRequest(url: URL(string: urlTF.stringValue)!, timeoutInterval: Double.infinity)
            request.httpBody = postData
        }else{// GET
            var params = ""
            if let bodyDict = srting2JsonObject(string: bodyTV.string) {
                for (index, kv) in bodyDict.enumerated() {
                    if index == 0 {
                        params += "?" + "\(kv.key)=\(kv.value)"
                    }else{
                        params += "&" + "\(kv.key)=\(kv.value)"
                    }
                }
            }
            
            if urlTF.stringValue.contains(where: {$0 == "?"}), let index = urlTF.stringValue.firstIndex(of: "?") {
                
                if params.isEmpty == false { // GET 请求， URL有参数且也输入了 JOSN 参数，按JSON 参数取值
                    urlTF.stringValue = String(urlTF.stringValue[urlTF.stringValue.startIndex..<index])
                }
            }
            
            request = URLRequest(url: URL(string: urlTF.stringValue + params)!, timeoutInterval: Double.infinity)
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpMethod = methodBtn.selectedItem?.title
        
        let item = XYItem()
        item.isLock = lockBtn.state.rawValue == 1
        item.name = nameTF.stringValue
        let res = XYRequest()
        res.method = request.httpMethod
        res.url = request.url?.absoluteString
        res.body = bodyTV.string
        item.request = res
        if item.name?.isEmpty == true {
            item.name = request.url?.host
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {

                let errMsg = String(describing: error)
                semaphore.signal()

                DispatchQueue.main.async {
                    self.resultTV.string = errMsg
                    item.response = errMsg
                    
                    self.refreshUIAndDataBase(item: item)
                }
                print(errMsg)
                return
            }

            var sucString = String(data: data, encoding: .utf8)!
            if sucString.isEmpty {
                sucString = response?.description ?? "请求完成，返回数据为空"
            }
            print(sucString)
            DispatchQueue.main.async {
                self.resultTV.string = sucString
                item.response = sucString
                
                self.refreshUIAndDataBase(item: item)
            }

            semaphore.signal()
        }

        task.resume()
        semaphore.wait()
        
        // 每次请求之后保存到本地。 暂时以 URL 做key，去重，后续扩展一个用户自定义名称来做 key
        
        
        
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
    
    func refreshUIAndDataBase(item: XYItem) {
        if self.lastSelectedRow < 0 {
            // 没有选中的时候，添加记录,如果有相同的请求地址，指定名称，自动去重
            if dataArray.last?.name == item.name {
                self.dataArray.replaceSubrange(dataArray.index(before: dataArray.endIndex)..<dataArray.endIndex, with: [item])
                self.tableView.reloadData()
                self.updateHistory()
            }else{
                self.dataArray.append(item)
                self.tableView.reloadData()
                self.updateHistory()
            }
        }else{
            // 已选中就直接更新记录
            let row = self.lastSelectedRow
            self.dataArray.replaceSubrange(row...row, with: [item])
            self.tableView.reloadData()
            self.updateHistory()
        }
    }
    
    @IBAction func deleteClick(_ sender: NSButton) {
        
//        XYAlert.showAlert(on: self.view, msg: "此删除操作不可恢复，确定删除") {
            if let cell = sender.superview as? NSTableCellView {
                self.deleteAction(cell: cell)
            }
//        } cancelCallBack: {
//            //取消，不做事
//        }
    }
    
    func deleteAction(cell: NSTableCellView) {
        if let title = cell.textField?.stringValue {
            for (index, item) in dataArray.enumerated() {
                if "\(index)" == title.components(separatedBy: ". ").first {
                    
                    if item.isLock == true {
                        showAlert(msg: "您要移除的记录为【" + title + "】它是锁定的记录，不能直接删除，需要先接触锁定")
                        return;
                    }
                    
                    dataArray.remove(at: index)
                    tableView.reloadData()
                    updateHistory()
                    break;
                }
            }
        }
        
        tableView.selectRowIndexes(IndexSet(integer: min(lastSelectedRow, dataArray.count-1)), byExtendingSelection: false)
    }
    
    func updateHistory() {
        
        // 每次关闭，写入最新数据
        let items = self.dataArray.map { item in
            item.toDictionary()
        }
        let dict = ["item": items]
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            let jsonStr = String(data: data, encoding: .utf8)
            try jsonStr?.write(toFile: history_path, atomically: true, encoding: .utf8)
            
            // showAlert(msg: jsonStr!)
            
        }catch{
            // 出错了，以后再说
            print(error)
        }
    }
}

extension NetRequestVC: NSTableViewDataSource {
  
    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataArray.count
    }
}

extension NetRequestVC: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let CellID = "cellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.CellID), owner: nil) as? NSTableCellView {
            
            let item = dataArray[row]
            
            cell.textField?.stringValue = "\(row). " + (item.name ?? "")
            //cell.layer?.backgroundColor = NSColor.red.cgColor
            cell.imageView?.image = NSImage(named: "im")
            
            return cell
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        lastSelectedRow = tableView.selectedRow
        
        if tableView.selectedRowIndexes.count == 1 {
            let item = dataArray[tableView.selectedRow]
            
            methodBtn.selectItem(withTitle: item.request?.method ?? "GET")
            nameTF.stringValue = item.name ?? ""
            urlTF.stringValue = item.request?.url ?? ""
            bodyTV.string = item.request?.body ?? ""
            resultTV.string = item.response ?? ""
            if item.isLock == true {
                lockBtn.state = NSControl.StateValue(rawValue: 1)
            }else{
                lockBtn.state = NSControl.StateValue(rawValue: 0)
            }
            
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        true
    }

}
