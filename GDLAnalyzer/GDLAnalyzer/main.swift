//
//  main.swift
//  GDLAnalyzer
//
//  Created by 张博 on 2021/1/20.
//

import Foundation
import Surge

var InPath:String = "/tmp/call-graph/Analyzer"
let OutPath = "/tmp/call-graph/Analyzer/dotFile"

if (CommandLine.argc >= 2) {
    InPath = CommandLine.arguments[1]
} else {
//    print("输入libtooling 生成json文件的路径")
//    exit(1)
}

//GDL模块合并
//var preprocessor = Preprocessor(originCGPath: InPath)
//GDLAnalyzer(W: preprocessor.W,nameList: preprocessor.classList);

var preprocessor = MethodsPreprocessor(originCGPath: InPath)
MethodsOutput(preprocessor: preprocessor, outputPath: OutPath)

//let diffStep = false;
//var lastOutput :Output? = nil
//if (diffStep) {
//    for step in stride(from: 1, to: 3500, by: 1) {
//        do {
//            let jsonData = try Data(contentsOf: URL(fileURLWithPath: OutPath + "modules_step_\(step).json"))
//            let clusters_Named = try JSONDecoder().decode([[String]].self, from: jsonData);
//
//            //每次run, classList,W,clusters都会变化，但他们的对应关系是不变的，变的只有每个类对应的序号，不影响结果计算
//            let clusters:[[Int]] = clusters_Named.map{$0.map{ preprocessor.classList.firstIndex(of:$0)! }}
//            var output = Output(clusers: clusters, nameMap: preprocessor.classList, W: preprocessor.W, moduleClassMap: preprocessor.moduleClsesMap, step: step)
//            output.targetModules = ["PPSTag"]
//
//            var needOutput = false
//            if (lastOutput != nil) {
//                let lastClusters = lastOutput!.moduleClustersMap["PPSTag"]!
//                let thisCluster = output.moduleClustersMap["PPSTag"]!
//                var equal = lastClusters.count == thisCluster.count
//                if (equal) {
//                    for i in 0..<lastClusters.count {
//                        equal = equal && lastClusters[i].count == thisCluster[i].count
//                    }
//                }
//
//                if (!equal) {
//                    needOutput = true
//                }
//            } else {
//                needOutput = true
//            }
//            if (needOutput) {
//                output.format6()
//            }
//            lastOutput = output
//        } catch {
//
//        }
//    }
//} else {
//
//    let step = 3100
//    let jsonData = try Data(contentsOf: URL(fileURLWithPath: OutPath + "modules_step_\(step).json"))
//    let clusters_Named = try JSONDecoder().decode([[String]].self, from: jsonData);
//
//    //每次run, classList,W,clusters都会变化，但他们的对应关系是不变的，变的只有每个类对应的序号，不影响结果计算
//    let clusters:[[Int]] = clusters_Named.map{$0.map{ preprocessor.classList.firstIndex(of:$0)! }}
//    var output = Output(clusers: clusters, nameMap: preprocessor.classList, W: preprocessor.W, moduleClassMap: preprocessor.moduleClsesMap, step: step)
//    output.formatClustersWhole()
//}

print("Hello, World!")

