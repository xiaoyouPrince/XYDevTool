//
//  NetModels.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2022/5/11.
//

/*
 {
     "item": [
         {
             "name": "New Request",
             "request": {
                 "method": "POST",
                 "header": [],
                 "body": "{\n    \"staffId\": 1098943659,\n    \"rootOrgId\": 130300385,\n    \"sideBusinessType\": \"OPERATION\",\n    \"sideBusinessSubtype\": \"TEST\"\n}",
                 "url":  "http://b-officialaccountresume-officialaccountresume.zpidc.com/adminService/sendRecommendActiveStaffEvent"
             },
             "response": []
         }
     ]
 }
 */

import Cocoa

class XYRequest: Model {
    
    /** POST */
    var method: String?
    
    var header: String?
    
    /** {
    "staffId": 1098943659,
    "rootOrgId": 130300385,
    "sideBusinessType": "OPERATION",
    "sideBusinessSubtype": "TEST"
} */    //  需要注意这个字段是个完整的 JSON String
    var body: String?
    
    /** http://b-officialaccountresume-officialaccountresume.zpidc.com/adminService/sendRecommendActiveStaffEvent */
    var url: String?
}

class XYItem: Model {
    
    /** New Request */
    var name: String?
    /// 是否锁定，锁定不能移除，防止误删
    var isLock: Bool?
    var request: XYRequest?
    var response: String?
}

class MyObj: Model {
    var item: [XYItem]?
}
