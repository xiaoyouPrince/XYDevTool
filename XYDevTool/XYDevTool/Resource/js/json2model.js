///
///
/// feature: revert Json to Swift class
/// auther: xiaoyou
/// date: 2022.04.29
///
///

/// FEATURE: - 
// 1. 自动 JSON 文件转换为 Swift Class，减少重复工作，降低出错概率
// 2. 自动解析嵌套类型 array 和 dictionary，并将嵌套类型的内容按实际解析成新的类
// 3. 对于数组类型自动解析其 dict 元素完整的键值，有效避免测试 Json 测试数据中数组元素key乱写/少写导致可能的丢失情况


/// TODO: - 
// 1. 支持自定义类前缀
// 2. 支持自定义类继承基类 + 遵守协议
// 3. 支持将原来字段的 value 设置为属性注释，方便后续维护的时候查看代码
// 4. 支持自动生成 CodingKeys, 方便后续直接使用系统 Codable 协议进行模型转换
// 5. 做成命令，支持帮助，提示各个参数含义

// enum CodingKeys: String, CodingKey {
//     case content
//     case id
//     case defaultSet
//     case sensitive
// }


let params = %@;

console.log(params);

//let jsonString = params;
let jsonString = params.jsonString;
let classPrefix = params.classPrefix;
let needComent = params.needComent;
let baseClass = params.baseClass;
let needCodingKeys = params.codingKeys;


//var fileManager = require('fs');
//const { removeAllListeners, exit } = require('process');
var gettype = Object.prototype.toString;

String.prototype.firstUpperCase = function titleCase() {
    let newStr = this.slice(0,1).toUpperCase() + this.slice(1)
    return newStr;
}

let br = "\n"
let tab = "\t"

//var arguments = process.argv.splice(2)
//var path = arguments[0]
//
//console.log(arguments);
//
//if (path) {
//    console.log(path);
//}else{
//    console.log("需要指定要解析的 JSON 文件路径");
//    exit(1);
//}

//console.log("nihao".toUpperCase());
//console.log("nihao".firstUpperCase());
//
var result = JSON.parse(jsonString)
console.log(result)
console.log("classPrefix = " + classPrefix)
console.log("needComent = " + needComent)
console.log("baseClass = " + baseClass)
console.log("needCodingKeys = " + needCodingKeys)


//
//
//console.log("nihao".toUpperCase());
//console.log("nihao".firstUpperCase());

var classArray = new Array()
parseObject("MyObj", result)

var json2model = function getAllResult(){
    
    var stringAll = ""
    for (var i = classArray.length - 1; i >= 0; i--){
        let clz = classArray[i]
        
        if( baseClass.length > 0 ) { // 是否设置继承基类
            stringAll += "class " + clz.name + ": " + baseClass + " {" + br
        }else
        {
            stringAll += "class " + clz.name + " {" + br
        }

        for (let j = 0; j < clz.property.length; j++) {
            const element = clz.property[j];
            stringAll += tab + element + br
        }
        
        if (needCodingKeys) { // 自动生成 CodingKeys
            // enum CodingKeys: String, CodingKey {
            //     case content
            // }
            
            stringAll += br + tab + "enum CodingKeys: String, CodingKey {" + br
            
            for (let j = 0; j < clz.property.length; j++) {
                var element = clz.property[j];
                if (element.substr(0,6) == "\n\t/** "){
                    element = ""
                    continue;
                }
                
                let theCase = element.replace("var ", "case ")
                theCase = theCase.split(": ")[0]
                stringAll += tab + tab + theCase + br
            }
            
            stringAll += tab + "}" + br
            
        }

        stringAll += "}" + br + br
    }

    console.log(stringAll);
    return stringAll
}

//  外界调用 json2model 即可



function parseObject(k, result){
    let c = new Class(k)
    classArray.push(c)

    for (let i = 0; i < Object.getOwnPropertyNames(result).length; i++) {
        const key = Object.getOwnPropertyNames(result)[i];
        var value = result[key]
        let type = getType(value)

        if (type == "null") {
            continue
        }

        if (type == "String" || type == "Int" || type == "Double" || type == "Bool") {
            if (needComent) { // 是否需要注释
                c.property.push("\n\t" + "/** " + value + " */")
            }
            c.property.push("var " + key + ": " + type + "?")
            continue
        }

        if (type == "Object") {
            if (Object.getOwnPropertyNames(value).length == 0) { // dict with zero key
                c.property.push("var " + key + ": " + "[String: Any]" + "?")
            }else{
                
                // 属性生成 + 类前缀
                let newClzName = key
                if (classPrefix.length > 0){
                    newClzName = classPrefix + key.firstUpperCase()
                    
                    parseObject(newClzName, value)
                    c.property.push("var " + key + ": " + newClzName + "?")
                }else
                {
                    parseObject(key.firstUpperCase(), value)
                    c.property.push("var " + key + ": " + key.firstUpperCase() + "?")
                }
                
                
            }

            continue
        }

        if (type == "Array") {
            if (value.length > 0){

                let obj = value[0]
                let objType = getType(obj)
                
                if (objType == "null") {
                    continue
                }

                if (objType == "Object") {
                    
                    // 属性生成 + 类前缀
                    let newClzName = key
                    if (classPrefix.length > 0){
                        newClzName = classPrefix + key.firstUpperCase()
                        
                        parseObject(newClzName, obj)
                        c.property.push("var " + key + ": " + "[" + newClzName + "]" + "?")
                    }else{
                        parseObject(key.firstUpperCase(), obj)
                        c.property.push("var " + key + ": " + "[" + key.firstUpperCase() + "]" + "?")
                    }
                    
                }else{
                    // 常规字符串等 数组嵌入数组的暂时没有处理
                    c.property.push("var " + key + ": " + "[" + objType + "]" + "?")
                }

                continue
            }// else {} // 空数组也没有处理
        }
    }
}

function getType(obj){
    if (typeof obj == 'number') {

        if (Number.isInteger(obj)) {
            return "Int"
        }else{
            return "Double"
        }
    }

    if (typeof obj == "boolean") {
        return "Bool"
    }

    if (typeof obj == "string") {
        return "String"
    }

    if (typeof obj == "undefined") {
        return "Any"
    }

    if (typeof obj == "null") {
        return "Any"
    }

    if (typeof obj == "function") {
        return "null"
    }

    if (typeof obj == "object") {
        if (gettype.call(obj) == "[object Object]") {
            return "Object"
        }

        if (gettype.call(obj) == "[object Array]") {
            return "Array"
        }

        if (gettype.call(obj) == "[object Null]") {
            return "Any"
        }
    }
}

function Class(name){
    this.name = name
    this.property = new Array()
}
