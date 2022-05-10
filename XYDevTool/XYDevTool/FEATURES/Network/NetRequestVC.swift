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
    
    
    @IBOutlet var resultTV: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        tableView.delegate = self
        tableView.dataSource = self
        
        
    }
    
    func getUrl() -> URL? {
        var string = urlTF.stringValue
        string = string.trimmingCharacters(in: .whitespacesAndNewlines)
        string = string.lowercased()
        
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            return URL(string: string)
        }else{
            return URL(string: "http://" + string)
        }
    }
    
    
    @IBAction func sendBtnClick(_ sender: Any) {
        
        guard let url = getUrl() else {
            showAlert(msg: "网址有误，输入正确的网址")
            return
        }
        
//        let url = URL(string: "http://b-officialaccountresume-officialaccountresume.zpidc.com/adminService/sendRecommendActiveStaffEvent")!
        
//        let url = URL(string: "http://127.0.0.1/json")!
        NetTool.post(url: url, paramters: [:], headers: [:]) {[weak self] result in
            
//            showAlert(msg: result.description)
            self?.resultTV.string = result.toString() ?? ""
            
        } failure: { errMsg in
            showAlert(msg: errMsg)
        }

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
