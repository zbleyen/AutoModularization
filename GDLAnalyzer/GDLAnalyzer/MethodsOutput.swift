//
//  MethodsOutput.swift
//  GDLAnalyzer
//
//  Created by 张博 on 2022/6/15.
//

import Foundation

class MethodsOutput {
    //               文件名   类名
    var originJson:[String:[String:ClsCallInfo]] = [:] //原始结构
    var methodClassMap:[String:String] = [:]            //方法->类
    var clsMethodsMap:[String:Set<String>] = [:]            //类->方法
//    var methodCallersMap:[String:[String:Int]] = [:]        //被调用方法 ->[调用类:调用次数]
    var classSuperMap:[String:String] = [:]             //类- 父类
    var outputPath = ""
    var validMethods:Set<String> = []
    
    init(preprocessor:MethodsPreprocessor,outputPath:String) {
        self.originJson = preprocessor.originJson
        self.methodClassMap = preprocessor.methodClassMap
//        self.methodCallersMap = preprocessor.methodCallersMap
        self.classSuperMap = preprocessor.classSuperMap
        self.outputPath = outputPath
        
        for (fileName, cls_methods) in self.originJson {
            for (cls, clsCallInfo) in cls_methods {
                var methods = Set<String>()
                if (clsCallInfo.methods == nil) {
                    continue
                }
                for (method,calees) in clsCallInfo.methods! {
                    methods.insert(method)
                }
                self.clsMethodsMap[cls] = methods
            }
        }
        for (method, cls) in self.methodClassMap {
            self.clsMethodsMap[cls]?.insert(method)
        }
                
        formatSVG()
        /*TODO 参照d3 force layout实现分组和交互的效果
         https://observablehq.com/@d3/gallery
         https://observablehq.com/@d3/force-directed-graph
         https://ialab.it.monash.edu/webcola/examples/smallworldwithgroups.html
         */
        
    }
    
    func formatSVG() {
        
        
//                    var edge =  "\"\(node)\" -> \"\(otherNode)\" [color=\"#ff0000\"];"
                    
        
        var edges:[String] = []
        
        var gs:String = ""
        gs += "digraph G  {\n";
        
        for (fileName, cls_methods) in self.originJson {
            for (cls, clsCallInfo) in cls_methods {
                if (clsCallInfo.methods == nil) {
                    continue
                }
                for (method,calees) in clsCallInfo.methods! {
                    for (calleeMethod,tf) in calees {
                        if let calleeCls = self.methodClassMap[calleeMethod] {  //剔除非编译方法
                            edges.append("\"\(method)\" -> \"\(calleeMethod)\" [color=\"#ff0000\"];")
                            validMethods.insert(method)
                            validMethods.insert(calleeMethod)
                        }
                    }
                }
            }
            
        }
        for edge in edges {
            gs += "\(edge)\n"
        }
        
        var i = 0
        for (cls, methods) in self.clsMethodsMap {
            gs += "subgraph cluster\(i) {\n graph [color = green,penwidth = 10,fontsize=50 ];\n label = \"\(cls)\";\n"
            for method in methods {
                gs += "\"\(method)\"\n"
            }
            gs += "}\n"
            i += 1
        }
                        
        
        gs += "}\n"
        
        do {
            try gs.write(toFile: OutPath + "/" + "dot.txt", atomically: true, encoding: .utf8)
        } catch {
            
        }
    }
    
    func write<T:Encodable>(data:T, to path:String) {
        
        do {
            let data = try JSONEncoder().encode(data)
            try data.write(to: URL(fileURLWithPath: path))
            print("结果写入到:\(path)")
        } catch {
            print("写结果失败")
        }
    }
}
