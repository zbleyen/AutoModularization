//
//  Preprocessor.swift
//  GDLAnalyzer
//
//  Created by 张博 on 2021/1/20.
//

import Foundation

extension String {
    subscript(_ range: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
        let end = index(start, offsetBy: min(self.count - range.lowerBound,
                                             range.upperBound - range.lowerBound))
        return String(self[start..<end])
    }

    subscript(_ range: CountablePartialRangeFrom<Int>) -> String {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
         return String(self[start...])
    }
}

struct ClsCallInfo : Decodable {
                //方法名  调用方法 及次数
    var methods:[String:[String:Float]]?
    var superClass:String?
    var relatedClasses:[String:Float]?
}

class Preprocessor {
    var originCGPath = ""   // libtooling生成的分散的json文件所在路径
    let cgExtension = "classCallees.json"
    let pathExtension = "filePath.json"
    
    //模块->文件
    //来自xcodeproj文件解析
    var moduleFilesMapFromProj:[String:[String]] = [:]
    var moduleFilesMap:[String:[String]] = [:]
    var filesModuleMap:[String:String] = [:]
    var moduleClsesMap:[String:[String]] = [:]
    
    //module -> xcodeproj文件地址 手写配置
    var moduleProjMap:[String:String] = [:]
    
    //来自json
    //               文件名   类名
    var originJson:[String:[String:ClsCallInfo]] = [:] //原始结构
    var filePathMap:[String:String] = [:]               //文件->路径
    
    
    var classFileMap:[String:String] = [:]              //类->文件
    var classIndexMap:[String:Int] = [:]                         //所有类 ->索引
    var classList:[String] = []
    
    var classSuperMap:[String:String] = [:]             //类- 父类
    var superClsIdfMap:[String:Float] = [:]             //父类idf
    
    var classRelatedClsMap:[String:[String:Float]] = [:]   //类 - property 类
    var relatedClsIdfMap:[String:Float] = [:]
    
    var methodClassMap:[String:String] = [:]            //方法->类
    var methodCallersMap:[String:[String:Int]] = [:]        //被调用方法 ->[调用类:调用次数]
    var methodIdfMap:[String:Float] = [:]
    var W:[[Float]] = []
    var N = 0
    
    init(originCGPath: String) {
        self.originCGPath = originCGPath
        preprocess()
    }
    func preprocess() {
        self.originJson = loadFiles(filter: cgExtension)
        self.filePathMap = loadFiles(filter: pathExtension)
        self.filePathMap = self.filePathMap.filter{ self.originJson[$0.key] != nil}
        getAllModule()
        getClassFileMap()
        
        self.N = self.classIndexMap.count
        self.W = Array(repeating: Array(repeating: 0, count: N), count: N);
        
        getMethodClassMap()
        getMethodCallersMap()
        getMethodIdfMap()
        getSuperIdfMap()
        getRelatedClsIdfMap()
        getW();
        normalizeW()   //按行进行归一化
        reverseDecorateW(); //有向图的反方向权重修饰一下
        getAllModuleFromProj()  //从projct文件中看一下源码都有哪些
    }
    
    //test
    func printCallee(row:Int) {
        print("this item is \(self.classList[row]),所有callee如下：")
        for column in (0..<N) {
            if (W[row][column] != 0) {
                print("\(column) 权重:\(W[row][column]) \(self.classList[column])")
            }
        }
    }
    
    func printCaller(column:Int) {
        print("this item is \(self.classList[column]),所有caller如下：")
        for row in (0..<N) {
            if (W[row][column] != 0) {
                print("\(row) 权重:\(W[row][column]) \(self.classList[row])")
            }
        }
    }
    
    func reverseDecorateW() {
        for rowIndex in (0..<N) {
            for columnIndex in (0..<N) {
                if (W[rowIndex][columnIndex] != 0 && W[columnIndex][rowIndex] == 0) {
                    var tRow = W[columnIndex]
                    tRow[rowIndex] = W[rowIndex][columnIndex] * 0.1
                    W[columnIndex] = tRow
                }
            }
        }
    }
    func normalizeW() {
        var rowWs:[Float] = []
        for rowIndex in (0..<N) {
            var row = W[rowIndex]
            var totalW:Float = 0
            
            for columnIndex in (0..<N) {
                totalW += row[columnIndex]
            }
            rowWs.append(totalW)
        }
        let middleW:Float = rowWs.sorted(by: {$0 > $1})[N/2]
        
        for rowIndex in (0..<N) {
            var row = W[rowIndex]
            var totalW:Float = rowWs[rowIndex]
            if (totalW > 0) {
                let normalizedRation = 1 / sqrt(max(totalW / middleW,1))          //对于出度总权重比较大的权重，进行向下调整
                for columnIndex in (0..<N) {
                    row[columnIndex] = row[columnIndex] *  normalizedRation     
                }
                W[rowIndex] = row
            }
        }
    }
    
    
    func getW() {
        
        let needAdjustWByModules = true
        
        var allCalleMethods:[[[String]]] = Array(repeating: Array(repeating: [], count: N), count: N)
        for (file,allCls) in self.originJson {
            for (cls,clsCall) in allCls {
                if (clsCall.methods == nil) {
                    continue
                }
                let rowIndex = self.classIndexMap[cls]!
                for (method,callInfo) in clsCall.methods! {
                    for (calleeMethod,tf) in callInfo {
                        if let calleeCls = self.methodClassMap[calleeMethod] {  //剔除非编译方法
                            if (calleeCls.compare(cls) == .orderedSame) {
                                continue
                            }
                            let columnIndex = self.classIndexMap[calleeCls]!
                            
                            //防止重复因为某个方法加权重
                            var methods = allCalleMethods[rowIndex][columnIndex]
                            if (methods.contains(calleeMethod)) {
                                continue
                            }
                            methods.append(calleeMethod)
                            allCalleMethods[rowIndex][columnIndex] = methods
                            
                            
                            let idf = self.methodIdfMap[calleeMethod]!
                            
                            var row = W[rowIndex]
                            var accumulated_w = row[columnIndex]
                            var w = 1 * idf //replace tf tf is to large
                             if (needAdjustWByModules &&   self.filesModuleMap[self.classFileMap[self.classList[rowIndex]]!]!.compare(self.filesModuleMap[self.classFileMap[self.classList[columnIndex]]!]!) != .orderedSame) {
                                w *= 0.5        //不同模块的调用权重缩放
                             }
                            accumulated_w += w
                            row[columnIndex] = accumulated_w
                            W[rowIndex] = row
                        }
                    }
                }
                if let superClass = clsCall.superClass{
                    if let columnIndex = self.classIndexMap[superClass] {
                        var row = W[rowIndex]
                        var accumulated_w = row[columnIndex]
                        accumulated_w += self.superClsIdfMap[superClass]!
                        row[columnIndex] = accumulated_w
                        W[rowIndex] = row
                    }
                }
                
                //TODO check
                if let relatedClsMap = clsCall.relatedClasses {
                    for (relatedCls,_ ) in relatedClsMap {
                        if let columnIndex = self.classIndexMap[relatedCls] {
                            var row = W[rowIndex]
                            var accumulated_w = row[columnIndex]
                            accumulated_w += self.relatedClsIdfMap[relatedCls]!
                            row[columnIndex] = accumulated_w
                            W[rowIndex] = row
                        }
                    }
                }
                
            }
        }
    }
    
    func getRelatedClsIdfMap() {
        var relatedClsDfMap:[String:Int] = [:]
        for (cls, relatedClses) in self.classRelatedClsMap {
            for (relatedCls,_ ) in relatedClses {
                if (self.classIndexMap[relatedCls] != nil) {
                    if let df = relatedClsDfMap[relatedCls] {
                        relatedClsDfMap[relatedCls] = df + 1
                    } else {
                        relatedClsDfMap[relatedCls] = 1;
                    }
                }
            }
        }
        for (relatedCls, count) in relatedClsDfMap {
            self.relatedClsIdfMap[relatedCls] = 7.0/Float(count)
        }
    }
    
    func getSuperIdfMap() {
        var superCountMap:[String:Int] = [:]
        for (_,superCls) in classSuperMap {
            if let count = superCountMap[superCls] {
                superCountMap[superCls] = count + 1
            } else {
                superCountMap[superCls] = 1
            }
        }
        for (superCls, count) in superCountMap {
            superClsIdfMap[superCls] =  7.0/Float(count)
        }
    }
    
    func getMethodIdfMap() {
        var maxCount = 0
        for (method, callers) in self.methodCallersMap {
            let df = callers.count
            if (maxCount < df) {
                maxCount = df
            }
        }
        
        for (method, callers) in self.methodCallersMap {
            let df = callers.count
            let idf =  7.0/Float(df)//log2(Float(fakedN) / Float(df))
            self.methodIdfMap[method] =  idf
        }
    }
    
    func getMethodCallersMap() {
        for (file,allCls) in self.originJson {
            for (cls,clsCall) in allCls {
                if (clsCall.methods == nil) {
                    continue
                }
                for (method,callInfo) in clsCall.methods! {
                    for calleeMethod in callInfo.keys {
                        var calleeCls = self.methodClassMap[calleeMethod]
                        if calleeCls == nil  {
                            if let firstSlice = calleeMethod.split(separator: Character(" ")).first {   //fix 编译类的非编译方法
                                calleeCls = String(firstSlice)[2...]
                                if (self.classIndexMap[calleeCls!] == nil) {    //过滤非编译类
                                    continue
                                } else {
                                    self.methodClassMap[calleeMethod] = calleeCls
                                }
                            } else {
                                continue
                            }
                            
                        }
                        if (calleeCls!.compare(cls) == .orderedSame) {
                            continue
                        }
                        var callers = self.methodCallersMap[calleeMethod]
                        if (callers == nil) {
                            callers = [:]
                        }
                        var thisClsCallCount = callers![cls]
                        if (thisClsCallCount == nil) {
                            thisClsCallCount = 1
                        } else {
                            thisClsCallCount = thisClsCallCount! + 1
                        }
                        callers![cls] = thisClsCallCount
                        self.methodCallersMap[calleeMethod] = callers
                    }
                }
                
                //额外操作 求classSuperMap
                if let superClass = clsCall.superClass {
                    if (classIndexMap[superClass] != nil) {
                        self.classSuperMap[cls] = superClass
                    }
                }
                
                if let relatedClsMap = clsCall.relatedClasses {
                    self.classRelatedClsMap[cls] = relatedClsMap
                }
            }
        }
    }
    
    func getMethodClassMap() {
        for (file,allCls) in self.originJson {
            for (cls,clsCall) in allCls {
                if (clsCall.methods == nil) {
                    continue
                }
                for method  in clsCall.methods!.keys {
                    self.methodClassMap[method] = cls
                }
            }
        }
    }
    
    func getClassFileMap () {
        for fileItem in self.originJson {
            for clsItem in fileItem.value.keys {
                self.classFileMap[clsItem] = fileItem.key
            }
        }
        //额外操作 求 classIndexMap
        var index = 0
        for clsItem in self.classFileMap.keys {
            self.classIndexMap[clsItem] = index
            self.classList.append(clsItem)
            index += 1
        }
    }
    
    func getAllModuleFromProj (){
        for module in self.moduleFilesMap.keys {
            let modulePath = "/Users/zhangbo/WorkSpace/"+module
            let rb = Process()
            rb.executableURL = URL(fileURLWithPath: "/Users/zhangbo/Analyzer/script/xcodproj_sourcefiles.rb")
            rb.arguments = [modulePath]
            var pipe = Pipe()

            rb.standardOutput = pipe
            do {
                try rb.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                  if let output = String(data: data, encoding: String.Encoding.utf8) {
                    let files = output.split(separator: Character("\n")).map{String($0)}
                    self.moduleFilesMapFromProj[module] = files
                  }
            } catch {
                
            }
            rb.waitUntilExit()
        }
    }
    
    
    func getAllModule() {
        for (file, path) in self.filePathMap {
            let components = path.split(separator: Character("/"))
            if (components.count > 4) {
                var moduleName:String = String(components[3])
                if (components.count > 6 && (components[3].compare("PPS") == .orderedSame && components[4].compare("Pods") == .orderedSame)) {
                    moduleName = String(components[5])
                }
                
                var files = self.moduleFilesMap[moduleName]
                if (files == nil) {
                    files = [file]
                } else {
                    files?.append(file)
                }
                self.moduleFilesMap[moduleName] = files
                self.filesModuleMap[file] = moduleName
                
                var clses:[String] = []
                for file in files! {
                    let json = self.originJson[file]
                    for cls in json!.keys {
                        clses.append(cls)
                    }
                }
                self.moduleClsesMap[moduleName] = clses
            }
        }
    }
    
    func loadFiles<Value:Decodable>(filter:String) -> [String:Value] {
        let manager = FileManager.default
        let url = URL(fileURLWithPath: originCGPath)
        let contentsOfPath = try? manager.contentsOfDirectory(atPath: url.path)
        var ret:[String:Value] = [:]
        
        let allTargetFiles = contentsOfPath?.filter{$0.hasSuffix(filter)}
        for targetFile in allTargetFiles! {
            do {
                let jsonData = try Data(contentsOf: url.appendingPathComponent(targetFile))
                let dic = try JSONDecoder().decode([String:Value].self, from: jsonData);
                if (dic.first?.key != nil) {
                    ret[dic.first?.key ?? ""] = dic.first?.value
                }
                
            } catch {
                
            }
        }
        return ret
    }
    

}
