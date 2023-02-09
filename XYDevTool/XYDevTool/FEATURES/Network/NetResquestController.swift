//
//  NetResquestController.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/12/21.
//  Copyright © 2022 XIAOYOU. All rights reserved.
//

import Cocoa

class NetResquestController: NSViewController {

    @IBOutlet var topView: NSView!
    
    @IBOutlet weak var leftView: LeftView!
    @IBOutlet weak var outlineView: NSOutlineView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        
        let t = pthread_self()
        print(t)
        print(t.self)
        
        let t2 = Thread.current
        print(t2)
        print(t2.self)
        
        
        
        
        view.xy_backgroundColor = .clear
        
        view.snp.makeConstraints { make in
            make.size.greaterThanOrEqualTo(CGSize(width: 800, height: 600))
        }
        
        view.addSubview(topView)
        topView.xy_backgroundColor = .init(r: 123, g: 161, b: 208)//.random
        topView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            //make.height.equalTo(90)
        }
        
        leftView.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(200)
        }
        
        let dataSource = OutLineViewDataSource()
//        outlineView.backgroundColor = .yellow
//        outlineView.delegate = dataSource
//        outlineView.dataSource = dataSource
        outlineView.reloadData()
    }
    
}



class OutLineViewDataSource: NSObject, BaseDataProtocol, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    var dataArray: [XYItem] = []
    
    override init() {
        super.init()
        
        if let data = NSData(contentsOfFile: history_path), let historys = MyObj.mapping(jsonData: data as Data) {
            dataArray = historys.item ?? []
//            tableView.reloadData()
            
            print("----- dataArray.count = \(dataArray.count)")
        }
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return dataArray.count
        }else{
            return (item as? Array<Any>)?.count ?? 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return dataArray[index]
        }else{
            return "item 下的内容"
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if item == nil {
            return nil
        }else{
            print("--------- item = \(item)")
            return (item as! XYItem).name
        }
    }
    
    fileprivate enum CellIdentifiers {
        static let CellID = "cellID"
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        
        print("----view for----- item = \(item)")
        
//        if let xyitem = item as? XYItem {
//            
//        }
        
        if let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.CellID), owner: nil) as? NSTableCellView {
            
//            let item = dataArray[row]
            if let xyitem = item as? XYItem {
                cell.textField?.stringValue =  (xyitem.name ?? "")
            }else {
                cell.textField?.stringValue =  "100"//(item.name ?? "")
            }
            
            
            //cell.layer?.backgroundColor = NSColor.red.cgColor
            cell.imageView?.image = NSImage(named: "AppIcon")
            cell.xy_backgroundColor = .random
            return cell
        }
        
        
        let v = NSView()
        v.xy_backgroundColor = .red
        
        return v
    }

}
