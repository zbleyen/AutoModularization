//
//  Output.swift
//  GDLAnalyzer
//
//  Created by 张博 on 2021/1/21.
//

import Foundation

class Output {
    
    var outJson1:[[String]] = []
    var outStr2:String = ""
    var outJson3:[String:[String]] = [:]    //module与clusters的之间差异  一个moduel对应一个cluster
    var outJson4:[String:[[String]]] = [:]    //module与clusters之间的差异 一个moduel对应多个cluster
    var outStr5:String = ""                 //各个模块按照dot格式输出
    
    var clusters:[[Int]] = []
    var nameMap:[String] = []
    var W:[[Float]] = []
    var step:Int = 0
    var moduleClassMap:[String:[String]] = [:]
    var targetModules = [""]
//    var blackListModules = ["QYRNContainer_pps","xcrash","QYRNBaselineModule","QYRNUIComponent","QYWebContainerJSSDKBase"]
    var blackListModules:[String] = []
    var moduleClustersMap:[String:[[Int]]] = [:]
    var aW:Float = 0    //平均权重
    
    init(clusers:[[Int]],nameMap:[String],step:Int) {
        self.clusters = clusers
        self.nameMap = nameMap
        self.step = step
        format1()
    }
    
    init(clusers:[[Int]],nameMap:[String],W:[[Float]], step:Int) {
        self.clusters = clusers
        self.nameMap = nameMap
        self.W = W
        self.step = step
        format2()
    }
    
    init(clusers:[[Int]],nameMap:[String],W:[[Float]], moduleClassMap:[String:[String]],step:Int) {
        self.clusters = clusers
        self.nameMap = nameMap
        self.W = W
        self.step = step
        self.moduleClassMap = moduleClassMap
//        aW = averageW() / 2;
        moduleClustersMap = self.moduleClassMap.mapValues{_ in []}
        for i in 0..<self.clusters.count {
            let cluster = self.clusters[i]
            var maxInteraction = 0
            var maxInteractionModuleName:String = ""
            for (moduleName,moduleclses) in self.moduleClassMap {
                let tmp = interaction(module: moduleclses, cluster: cluster)
                if (tmp > maxInteraction) {
                    maxInteraction = tmp
                    maxInteractionModuleName = moduleName
                }
                
            }
            if (maxInteraction > 0) {
                moduleClustersMap[maxInteractionModuleName]!.append(cluster)
            }
        }
        
//        format3()
//        format4()
    }
    
    func averageW() -> Float {
        var count = 0
        var totalW:Float = 0
        for i in 0..<W.count {
            for j in 0..<W.count {
                if (W[i][j] > W[j][i]) {
                    count += 1
                    totalW += W[i][j]
                }
            }
        }
        if (count > 0) {
            return totalW / Float(count)
        }
        return 0
    }
    
    
    func formatClustersWhole() {
        
        //计算某个cluster与所有module的相似性，并排序
        func clusterCompareModules(cluster:[String]) -> [(String,Float)] {
            var moduleInterMap :[String:Float] = [:]
            for (moduleName,clses) in self.moduleClassMap {
                
                moduleInterMap[moduleName] = Float(cluster.filter{clses.contains($0)}.count) / Float(cluster.count)
            }
            return moduleInterMap.sorted { $0.1 > $1.1 }
        }
        
        //给cluster命名 {命名：[cluster]}
        var clusterClsesMap:[String:[String]] = [:]
        for i in 0..<clusters.count {

            let cluster = clusters[i].map{nameMap[$0]}
            var clusterName = ""//\(cluster.count)"
            var total:Float = 0
            var n:Int = 0
            for (moduleName,percent) in clusterCompareModules(cluster: cluster) {
                if (clusterName.count > 0) {
                    clusterName += ","
                }
                clusterName +=  String(format: "%2d%%", Int(percent * 100)) + "\(moduleName)"
                total += percent
                n += 1
                if (total > 0.8 || n > 2) {
                    break
                }
            }
            clusterName += "_\(cluster.count)"
            if (clusterClsesMap[clusterName] != nil) {
                clusterName += "_\(i)"
            }
            clusterClsesMap[clusterName] = cluster
        }
        
        //每个节点所属cluster {节点名：cluster名}
        var classClusterMap:[String:String] = [:]
        for (moduleName,moduleclses) in clusterClsesMap {
            for cls in moduleclses {
                classClusterMap[cls] = moduleName
            }
        }
        
        var classModuleMap:[String:String] = [:]
        for (moduleName,moduleclses) in self.moduleClassMap {
            for cls in moduleclses {
                classModuleMap[cls] = moduleName
            }
        }
        
        
        //找出以节点node为顶点、以cluster聚类外的其他点为另一个顶点的边
        func edges(node:String,out cluster:[String], nodeList:inout [String]) -> [String]{
            
            var edges:[String] = []
            let index = self.nameMap.firstIndex(of: node)!
            var degreeOutNodes:[String:Float] = [:]
            var degreeInNodes:[String:Float] = [:]
            //作为caller
            for j in 0..<self.W.count {
                if (W[index][j] > W[j][index]) {
                    var needAdd = false
//                    if !cluster.contains(j) {
                        needAdd = true
                    //                    }
                        if (needAdd) {
                            var otherNode = self.nameMap[j]
                            degreeOutNodes[otherNode] = W[index][j]
                        }
                        

                }
            }
                
            for i in 0..<self.W.count {
                if (W[i][index] > W[index][i]) {
                    var needAdd = false
//                    if !cluster.contains(i) {
                        needAdd = true
//                    }
                    
                    if (needAdd) {
                        var otherNode = self.nameMap[i]
                        degreeInNodes[otherNode] = W[i][index]
                    }
                    
                }
            }
            let sortedOutNodes = degreeOutNodes.sorted { $0.1 > $1.1 }
            let sortedInNodes = degreeInNodes.sorted { $0.1 > $1.1 }
                
            
            let MaxEdgeCount = 1;
            var i = 0;
            for (otherNode,w) in sortedOutNodes {
                if (!cluster.contains(otherNode) && w > aW ) {
//                    "\"\(classModuleMap[node]!)::\(node)\""
                    
                    var edge =  "\"\(classModuleMap[node]!)::\(node)\" -> \"\(classModuleMap[otherNode]!)::\(otherNode)\" [color=\"#ff0000\"];"
                    if (!edges.contains(edge)) {
                        edges.append(edge)
                    }
                    if (!nodeList.contains(otherNode)) {
                        nodeList.append(otherNode)
                    }
                }

                i += 1
                if (i > MaxEdgeCount) {
                    break;
                }
            }
            
            i = 0
            for (otherNode,w) in sortedInNodes {
                if (!cluster.contains(otherNode) && w > aW ) {
                    var edge = "\"\(classModuleMap[otherNode]!)::\(otherNode)\" -> \"\(classModuleMap[node]!)::\(node)\" [color=\"#ff0000\"];"
                    if (!edges.contains(edge)) {
                        edges.append(edge)
                    }
                    if (!nodeList.contains(otherNode)) {
                        nodeList.append(otherNode)
                    }
                }
                i += 1
                if (i > MaxEdgeCount) {
                    break;
                }
            }
            
//            var topEdges
            return edges
        }
        

        //各cluster中包含的“值得关注节点” {cluster名：[cluster中的“值得关注节点”]}
        var moduleConcerNodesMap:[String:[String]] = clusterClsesMap.mapValues{_ in []}
        var allEdges:[String] = []
        for (moduleName,clses) in clusterClsesMap {
            var concernEdges:[String] = []
            var nodes:[String] = []
            for cls in clses {
                let tmpEdges = edges(node: cls, out: clses, nodeList: &nodes)
                concernEdges += tmpEdges
//                if (tmpEdges.count > 0) {
                    moduleConcerNodesMap[moduleName]?.append(cls)
//                }
            }
            allEdges += concernEdges.filter{!allEdges.contains($0)}
            for node in nodes {
                moduleConcerNodesMap[classClusterMap[node]!]?.append(node)
            }

        }
        var gs:String = ""
        gs += "digraph G  {\n";
        
        for edge in allEdges {
            gs += "\(edge)\n"
        }
        
        var i = 0
        //只输出关注节点
        for (module, nodes) in moduleConcerNodesMap {
        //输出全部节点
//        for (module, nodes) in clusterClsesMap {
            if nodes.count > 3 {
                i += 1
                gs += "subgraph cluster\(i) {\n graph [color = green,penwidth = 15,fontsize=50 ];\n label = \"\(module)\";\n"
                
                for node in nodes {
                    gs += "\"\(classModuleMap[node]!)::\(node)\"\n"
                }
                let otherNodes = clusterClsesMap[module]
                for node in otherNodes! {
                    if (!nodes.contains(node)) {
                        gs += "\"\(classModuleMap[node]!)::\(node)\"\n"
                    }
                }
                gs += "}\n"
            }
        }
        
        gs += "}\n"
        
        do {
            try gs.write(toFile: OutPath + "tmp/" + "modules_step_\(step)_whole_clusters.txt", atomically: true, encoding: .utf8)
        } catch {
            
        }
    }
    
    func formatWhole() {
        var classModuleMap:[String:String] = [:]
        for (moduleName,moduleclses) in self.moduleClassMap {
            for cls in moduleclses {
                classModuleMap[cls] = moduleName
            }
        }
        
        func edges(node:String,out cluster:[String], nodeList:inout [String]) -> [String]{
            
            var edges:[String] = []
            let index = self.nameMap.firstIndex(of: node)!
            var degreeOutNodes:[String:Float] = [:]
            var degreeInNodes:[String:Float] = [:]
            //作为caller
            for j in 0..<self.W.count {
                if (W[index][j] > W[j][index]) {
                    var needAdd = false
//                    if !cluster.contains(j) {
                        needAdd = true
                    //                    }
                        if (needAdd) {
                            var otherNode = self.nameMap[j]
                            degreeOutNodes[otherNode] = W[index][j]
                        }
                        

                }
            }
                
            for i in 0..<self.W.count {
                if (W[i][index] > W[index][i]) {
                    var needAdd = false
//                    if !cluster.contains(i) {
                        needAdd = true
//                    }
                    
                    if (needAdd) {
                        var otherNode = self.nameMap[i]
                        degreeInNodes[otherNode] = W[i][index]
                    }
                    
                }
            }
            let sortedOutNodes = degreeOutNodes.sorted { $0.1 > $1.1 }
            let sortedInNodes = degreeInNodes.sorted { $0.1 > $1.1 }
                
            
            let MaxEdgeCount = 1;
            var i = 0;
            for (otherNode,w) in sortedOutNodes {
                if (!cluster.contains(otherNode) && w > aW && !blackListModules.contains(classModuleMap[otherNode]!)) {
                    var edge =  "\"\(node)\" -> \"\(otherNode)\" [color=\"#ff0000\"];"
                    if (!edges.contains(edge)) {
                        edges.append(edge)
                    }
                    if (!nodeList.contains(otherNode)) {
                        nodeList.append(otherNode)
                    }
                }

                i += 1
                if (i > MaxEdgeCount) {
                    break;
                }
            }
            
            i = 0
            for (otherNode,w) in sortedInNodes {
                if (!cluster.contains(otherNode) && w > aW && !blackListModules.contains(classModuleMap[otherNode]!)) {
                    var edge = "\"\(otherNode)\" -> \"\(node)\" [color=\"#ff0000\"];"
                    if (!edges.contains(edge)) {
                        edges.append(edge)
                    }
                    if (!nodeList.contains(otherNode)) {
                        nodeList.append(otherNode)
                    }
                }
                i += 1
                if (i > MaxEdgeCount) {
                    break;
                }
            }
            
//            var topEdges
            return edges
        }
        

        
        var moduleConcerNodesMap = self.moduleClassMap.mapValues{_ in []}
        var allEdges:[String] = []
        for (moduleName,clses) in moduleClassMap {
            if (blackListModules.contains(moduleName)) {
                continue
            }
            var concernEdges:[String] = []
            var nodes:[String] = []
            for cls in clses {
                let tmpEdges = edges(node: cls, out: clses, nodeList: &nodes)
                concernEdges += tmpEdges
                if (tmpEdges.count > 0) {
                    moduleConcerNodesMap[moduleName]?.append(cls)
                }
            }
            allEdges += concernEdges.filter{!allEdges.contains($0)}
            for node in nodes {
                moduleConcerNodesMap[classModuleMap[node]!]?.append(node)
            }

        }
        var gs:String = ""
        gs += "digraph G  {\n";
        
        for edge in allEdges {
            gs += "\(edge)\n"
        }
        
        var i = 0
        for (module, nodes) in moduleConcerNodesMap {
            if nodes.count > 0 {
                i += 1
                gs += "subgraph cluster\(i) {\n graph [color = green,penwidth = 10,fontsize=50 ];\n label = \"\(module)\";\n"
                
                for node in nodes {
                    gs += "\"\(node)\"\n"
                }
                gs += "}\n"
            }
        }
        
        gs += "}\n"
        
        do {
            try gs.write(toFile: OutPath + "tmp/" + "modules_step_\(step)_whole.txt", atomically: true, encoding: .utf8)
        } catch {
            
        }
    }
    
    func format6()  {

        
        var classModuleMap:[String:String] = [:]
        for (moduleName,moduleclses) in self.moduleClassMap {
            for cls in moduleclses {
                classModuleMap[cls] = moduleName
            }
        }
        
        func maxW(in cluster:[Int]) ->Float {
            var maxW:Float = 0.001
            for i in 0..<self.W.count {
                if !cluster.contains(i) {
                    continue
                }
                for j in 0..<self.W.count {
                    if (j == i || !cluster.contains(j)) {
                        continue
                    }
                    if W[i][j] > maxW {
                        maxW = W[i][j]
                    }
                }
            }
            return maxW
        }
        

        func edges(node:String,in cluster:[Int]?,maxW:Float?, hideTrivial:Bool,nodeList:inout [String]) -> [String]{
            
            var edges:[String] = []
            let index = self.nameMap.firstIndex(of: node)!
            var degreeOutNodes:[String:Float] = [:]
            var degreeInNodes:[String:Float] = [:]
            //作为caller
            for j in 0..<self.W.count {
                if (W[index][j] > W[j][index]) {
                    var needAdd = false
                    if (cluster != nil ) {
                        if cluster!.contains(j) {
                            needAdd = true
                        }
                    } else {
                        needAdd = true
                        
                    }
                    if (needAdd) {
                        var otherNode = ""
                        if (hideTrivial) {
                           otherNode = classModuleMap[self.nameMap[j]]!
                        } else {
                            otherNode = self.nameMap[j]
                        }
                        degreeOutNodes[otherNode] = W[index][j]
                    }
                    
                }
            }
            
            for i in 0..<self.W.count {
                if (W[i][index] > W[index][i]) {
                    var needAdd = false
                    if (cluster != nil ) {
                        if cluster!.contains(i) {
                            needAdd = true
                        }
                    } else {
                        needAdd = true
                        
                    }
                    
                    if (needAdd) {
                        var otherNode = ""
                        if (hideTrivial) {
                            otherNode = classModuleMap[self.nameMap[i]]!
                        } else {
                            otherNode = self.nameMap[i]
                        }
                        degreeInNodes[otherNode] = W[i][index]
                    }
                    
                }
            }
            
            for (otherNode,w) in degreeOutNodes {
                var edge =  "\"\(node)\" -> \"\(otherNode)\""
                if let maxW = maxW {
                    let alpha = String(format:"%02X", Int(w/maxW * 255))
                    edge += " [color=\"#000000\(alpha)\"]"
                }
                edge += ";"
                if (!edges.contains(edge)) {
                    edges.append(edge)
                }
                if (!nodeList.contains(otherNode)) {
                    nodeList.append(otherNode)
                }
            }
            
            for (otherNode,w) in degreeInNodes {
                var edge = "\"\(otherNode)\" -> \"\(node)\""
                if let maxW = maxW {
                    let alpha = String(format:"%02X", Int(w/maxW * 255))
                    edge += " [color=\"#000000\(alpha)\"]"
                }
                edge += ";"
                if (!edges.contains(edge)) {
                    edges.append(edge)
                }
                if (!nodeList.contains(otherNode)) {
                    nodeList.append(otherNode)
                }
            }
            
//            var topEdges
            return edges
        }
        

        let showEdges = true
        
        for (moduleName,clusters) in moduleClustersMap {
            if (!targetModules.contains(moduleName)) {
                continue
            }
            var plusNodeList:[String] = []  //在cluster不在module  yellow
            var minusNodeList:[String] = [] //在module不再cluster  red
            var rightNodeList:[String] = []     //既在module,也在cluster
            var edgesOfRightNode:[String] = []  //内部边
            var edgesOfPlusNode:[String] = []   //plus node 相连的所有边
            var edgesOfMinusNode:[String] = []  //minus node相连的所有边
            var subGraphs:[[String]] = []       //
            
            var edgeNodeOfPlusNode:[String] = []    //edgesOfPlusNode 的节点
            var edgeNodeOfMinusNode:[String] = []   //edgesOfMinusNode的节点
            var edgeNodeOfRightNode:[String] = []   //edgesOfRightNode的节点
            for cluster in clusters {
                let maxWeight = maxW(in: cluster)
                var clsesInCluster = cluster.map{self.nameMap[$0]}
                subGraphs.append(clsesInCluster)
                for cls in clsesInCluster {
                    if (classModuleMap[cls]!.compare(moduleName) == .orderedSame) {
                        rightNodeList.append(cls)
                        let thisEdges = edges(node: cls, in: cluster,maxW: maxWeight, hideTrivial:false,nodeList: &edgeNodeOfRightNode)
                        edgesOfRightNode += thisEdges.filter{!edgesOfRightNode.contains($0)}
                        
                    } else {
                        plusNodeList.append(cls)
                        edgesOfPlusNode += edges(node: cls, in: cluster, maxW:maxWeight, hideTrivial: false,nodeList: &edgeNodeOfPlusNode).filter{!edgesOfPlusNode.contains($0)}
                    }
                }
            }
            //计算的有重复，过滤一下
            edgesOfRightNode = edgesOfRightNode.filter{!edgesOfPlusNode.contains($0)}
            
            minusNodeList = self.moduleClassMap[moduleName]!.filter{!rightNodeList.contains($0)}
            let tmpMinusCluster = minusNodeList.map{self.nameMap.firstIndex(of: $0)!}
            for node in minusNodeList {
                edgesOfMinusNode += edges(node: node, in: tmpMinusCluster,maxW:nil, hideTrivial: false,nodeList: &edgeNodeOfMinusNode).filter{!edgesOfMinusNode.contains($0)}
            }
            
            var gs:String = ""
            gs += "digraph G  {\n";
            
            //聚类引入的点 和没有聚到的点
            var nodesConcern:[String] = minusNodeList + plusNodeList
            for node in minusNodeList {
                gs += "\"\(node)\" [fillcolor = red,style=filled]\n"
            }
            for node in plusNodeList {
                gs += "\"\(node)\"[fillcolor = yellow,style=filled]\n"
            }
            nodesConcern += rightNodeList
            for node in rightNodeList {
                gs += "\"\(node)\"\n"
            }
            
            //由两类点 连接的其他点
            var nodeOfEdges = edgeNodeOfMinusNode
            nodeOfEdges += edgeNodeOfPlusNode.filter{!nodeOfEdges.contains($0)};

            //self.moduleClassMap[moduleName]! + plusNodeList = 所有聚类的点
            //得到所有聚类之外的点
            let nodeOfOtherModule = nodeOfEdges.filter{!self.moduleClassMap[moduleName]!.contains($0) && !plusNodeList.contains($0)}
            
//            for node in nodeOfOtherModule {
//                gs += "\"\(node)\"[fillcolor = gray,style=filled]\n"
//            }
            
            if (showEdges) {
                for edge in edgesOfMinusNode {
                    gs += "\(edge)\n"
                }
                for edge in edgesOfPlusNode {
                    gs += "\(edge)\n"
                }
                for edge in edgesOfRightNode {
                    gs += "\(edge)\n"
                }
            }
            
            for i in 0..<subGraphs.count {
                let subg = subGraphs[i]
                var subGs = ""
                var nodeCount = 0
                
                for n in subg {
                    // module 中或者聚类引入的点
                    if (self.moduleClassMap[moduleName]!.contains(n) || nodesConcern.contains(n)) {
                        subGs += "\"\(n)\"\n"
                        nodeCount += 1
                    }
                }
                if (nodeCount > 1) {
                    gs += "subgraph cluster\(i) {\n graph [color = green,penwidth = 2];\n"
                    
                    gs += subGs
                    gs += "}\n"
                }
                
            }
            
            gs += "}\n"
            
            do {
                try gs.write(toFile: OutPath + "tmp/" + "modules_step_\(step)_\(moduleName)_allNodes.txt", atomically: true, encoding: .utf8)
            } catch {
                
            }
            var x = 0;
        }

    }
    
    func format5() {
        var moduleClustersMap:[String:[[Int]]] = self.moduleClassMap.mapValues{_ in []}
        for i in 0..<self.clusters.count {
            let cluster = self.clusters[i]
            var maxInteraction = 0
            var maxInteractionModuleName:String = ""
            for (moduleName,moduleclses) in self.moduleClassMap {
                let tmp = interaction(module: moduleclses, cluster: cluster)
                if (tmp > maxInteraction) {
                    maxInteraction = tmp
                    maxInteractionModuleName = moduleName
                }
                
            }
            if (maxInteraction > 0) {
                moduleClustersMap[maxInteractionModuleName]!.append(cluster)
            }
        }
        
        var classModuleMap:[String:String] = [:]
        for (moduleName,moduleclses) in self.moduleClassMap {
            for cls in moduleclses {
                classModuleMap[cls] = moduleName
            }
        }
        
        let hideTrivial = true

        func edges(node:String,in module:String?,hideTrivial:Bool,nodeList:inout [String]) -> [String]{
            
            var edges:[String] = []
            let index = self.nameMap.firstIndex(of: node)!
            //作为caller
            for j in 0..<self.W.count {
                if (W[index][j] > W[j][index]) {
                    var needAdd = false
                    if (module != nil ) {
                        if classModuleMap[self.nameMap[j]]!.compare(module!) == .orderedSame {
                            needAdd = true
                        }
                    } else {
                        needAdd = true
                        
                    }
                    if (needAdd) {
                        var otherNode = ""
                        if (hideTrivial) {
                           otherNode = classModuleMap[self.nameMap[j]]!
                        } else {
                            otherNode = self.nameMap[j]
                        }
                        let edge = "\"\(node)\" -> \"\(otherNode)\";"
                        if (!edges.contains(edge)) {
                            edges.append(edge)
                        }
                        if (!nodeList.contains(otherNode)) {
                            nodeList.append(otherNode)
                        }
                    }
                    
                }
            }
            
            for i in 0..<self.W.count {
                if (W[i][index] > W[index][i]) {
                    var needAdd = false
                    if (module != nil ) {
                        if classModuleMap[self.nameMap[i]]!.compare(module!) == .orderedSame {
                            needAdd = true
                        }
                    } else {
                        needAdd = true
                        
                    }
                    
                    if (needAdd) {
                        var otherNode = ""
                        if (hideTrivial) {
                            otherNode = classModuleMap[self.nameMap[i]]!
                        } else {
                            otherNode = self.nameMap[i]
                        }
                        let edge = "\"\(otherNode)\" -> \"\(node)\";"
                        if (!edges.contains(edge)) {
                            edges.append(edge)
                        }
                        if (!nodeList.contains(otherNode)) {
                            nodeList.append(otherNode)
                        }
                    }
                    
                }
            }
            return edges
        }
        

        
        
        for (moduleName,clusters) in moduleClustersMap {
            var plusNodeList:[String] = []  //在cluster不在module  yellow
            var minusNodeList:[String] = [] //在module不再cluster  red
            var rightNodeList:[String] = []     //既在module,也在cluster
            var edgesOfRightNode:[String] = []  //内部边
            var edgesOfPlusNode:[String] = []   //plus node 相连的所有边
            var edgesOfMinusNode:[String] = []  //minus node相连的所有边
            var subGraphs:[[String]] = []       //
            
            var edgeNodeOfPlusNode:[String] = []    //edgesOfPlusNode 的节点
            var edgeNodeOfMinusNode:[String] = []   //edgesOfMinusNode的节点
            var edgeNodeOfRightNode:[String] = []   //edgesOfRightNode的节点
            for cluster in clusters {
                var clsesInCluster = cluster.map{self.nameMap[$0]}
                subGraphs.append(clsesInCluster)
                for cls in clsesInCluster {
                    if (classModuleMap[cls]!.compare(moduleName) == .orderedSame) {
                        rightNodeList.append(cls)
                        let thisEdges = edges(node: cls, in: moduleName,hideTrivial:false,nodeList: &edgeNodeOfRightNode)
                        edgesOfRightNode += thisEdges.filter{!edgesOfRightNode.contains($0)}
                        
                    } else {
                        plusNodeList.append(cls)
                        edgesOfPlusNode += edges(node: cls, in: nil,hideTrivial: false,nodeList: &edgeNodeOfPlusNode).filter{!edgesOfPlusNode.contains($0)}
                    }
                }
            }
            minusNodeList = self.moduleClassMap[moduleName]!.filter{!rightNodeList.contains($0)}
            for node in minusNodeList {
                edgesOfMinusNode += edges(node: node, in: nil, hideTrivial: false,nodeList: &edgeNodeOfMinusNode).filter{!edgesOfMinusNode.contains($0)}
            }
            
            var gs:String = ""
            gs += "digraph G  {\n";
            
            //聚类引入的点 和没有聚到的点
            var nodesConcern:[String] = minusNodeList + plusNodeList
            for node in minusNodeList {
                gs += "\"\(node)\" [fillcolor = red,style=filled]\n"
            }
            for node in plusNodeList {
                gs += "\"\(node)\"[fillcolor = yellow,style=filled]\n"
            }
            if (!hideTrivial) {
                nodesConcern += rightNodeList
                for node in rightNodeList {
                    gs += "\"\(node)\"\n"
                }
            }
            
            //由两类点 连接的其他点
            var nodeOfEdges = edgeNodeOfMinusNode
            nodeOfEdges += edgeNodeOfPlusNode.filter{!nodeOfEdges.contains($0)};

            //self.moduleClassMap[moduleName]! + plusNodeList = 所有聚类的点
            //得到所有聚类之外的点
            let nodeOfOtherModule = nodeOfEdges.filter{!self.moduleClassMap[moduleName]!.contains($0) && !plusNodeList.contains($0)}
            for node in nodeOfOtherModule {
                gs += "\"\(node)\"[fillcolor = gray,style=filled]\n"
            }
            
            
            for edge in edgesOfMinusNode {
                gs += "\(edge)\n"
            }
            for edge in edgesOfPlusNode {
                gs += "\(edge)\n"
            }
            
            
            if (!hideTrivial) {
                for edge in edgesOfRightNode {
                    gs += "\(edge)\n"
                }
            }
            
            for i in 0..<subGraphs.count {
                let subg = subGraphs[i]
                var subGs = ""
                var nodeCount = 0
                
                for n in subg {
                    //边上的点或者关心的点（两类点）
                    if (nodeOfEdges.contains(n) || nodesConcern.contains(n)) {
                        subGs += "\"\(n)\"\n"
                        nodeCount += 1
                    }
                }
                if (nodeCount > 1) {
                    gs += "subgraph cluster\(i) {\n"
                    gs += subGs
                    gs += "}\n"
                }
                
            }
            
            gs += "}\n"
            
            do {
                try gs.write(toFile: OutPath + "modules_step_\(step)_\(moduleName).txt", atomically: true, encoding: .utf8)
            } catch {
                
            }
            var x = 0;
        }

    }
    
    
    /// 以cluster的维度去比较
    func format4() {
        var moduleClustersMap:[String:[[Int]]] = self.moduleClassMap.mapValues{_ in []}
        for i in 0..<self.clusters.count {
            let cluster = self.clusters[i]
            var maxInteraction = 0
            var maxInteractionModuleName:String = ""
            for (moduleName,moduleclses) in self.moduleClassMap {
                let tmp = interaction(module: moduleclses, cluster: cluster)
                if (tmp > maxInteraction) {
                    maxInteraction = tmp
                    maxInteractionModuleName = moduleName
                }
                
            }
            if (maxInteraction > 0) {
                moduleClustersMap[maxInteractionModuleName]!.append(cluster)
            }
        }
        
        var classModuleMap:[String:String] = [:]
        for (moduleName,moduleclses) in self.moduleClassMap {
            for cls in moduleclses {
                classModuleMap[cls] = moduleName
            }
        }
        
        self.outJson4 = self.moduleClassMap.mapValues{_ in []}
        for (moduleName,clusters) in moduleClustersMap {
            for cluster in clusters {
                var clsesInCluster = cluster.map{self.nameMap[$0]}
                var clsesDiff:[String] = []
                for cls in clsesInCluster {
                    if (classModuleMap[cls]!.compare(moduleName) == .orderedSame) {
                        clsesDiff.append(cls)
                    } else {
                        clsesDiff.append("++ \(classModuleMap[cls]!)::\(cls) ")
                    }
                }
                self.outJson4[moduleName]?.append(clsesDiff)
            }
        }
        write(data: self.outJson4, to: OutPath + "modules_diffs_step_\(step).json")
    }
    
    /// 以module的维度去比较
    func format3()  {
        var moduleClusterMap:[String:Int] = [:]     //最相似聚类的索引
        var moduleMatchmentMap:[String:Int] = [:]   //与最相似聚类的重合数
        
        func suggestModuleName(clsName:String) -> String {
            for (moduleName,clusterIndex) in moduleClusterMap{
                let cluster = self.clusters[clusterIndex].map{self.nameMap[$0]}
                if (cluster.contains(clsName)) {
                    return moduleName
                }
            }
            return ""
        }
        
        func fromModuleName(clsName:String) -> String {
            for (moduleName,clses) in self.moduleClassMap {
                if clses.contains(clsName) {
                    return moduleName
                }
            }
            return ""
        }
        
        for (moduleName,moduleclses) in self.moduleClassMap {
            var maxInteraction = 0
            var maxInteractionCluster:Int = 0
            for i in 0..<self.clusters.count {
                let cluster = self.clusters[i]
                let tmp = interaction(module: moduleclses, cluster: cluster)
                if (tmp > maxInteraction) {
                    maxInteraction = tmp
                    maxInteractionCluster = i
                }
            }
            if (maxInteraction > 0) {
                moduleClusterMap[moduleName] = maxInteractionCluster
                moduleMatchmentMap[moduleName] = maxInteraction
            }
        }
        for (moduleName,clusterIndex) in moduleClusterMap {
            let moduleclses = self.moduleClassMap[moduleName]!
            let cluster = self.clusters[clusterIndex].map{self.nameMap[$0]}
            let minus = moduleclses.filter{!cluster.contains($0)}
            let plus = cluster.filter{!moduleclses.contains($0)}
            var strs:[String] = []
            strs.append("重合类数量：\(moduleMatchmentMap[moduleName])")
            strs += minus.map{"-- \($0) \t-->" + suggestModuleName(clsName:$0)}     //module中有，cluster中没有，
            strs += plus.map{"++ \($0) \t<--" + fromModuleName(clsName:$0)}     //module中有，cluster中没有，
            outJson3[moduleName] = strs;
        }
        
        write(data: self.outJson3, to: OutPath + "modules_final_step_\(step).json")
        
    }
    
    func interaction(module:[String],cluster:[Int]) -> Int {
        let clusterClsNames = cluster.map{self.nameMap[$0]}
        return module.filter{clusterClsNames.contains($0)}.count
    }
    
    func format2() {
        var gs = ""
        gs += "digraph G {\n"
        for node in nameMap {
            gs += "\(node)\n"
        }
        
        let to:[Float] = [0.2,1.5]
        var from:[Float] = [10000,0.0001]
        for i in 0..<W.count {
            for j in 0..<W.count {
                let w = W[i][j]
                if w > 0 {
                    if (from[1] < w) {
                        from[1] = w
                    }
                    if (from[0] > w) {
                        from[0] = w
                    }
                }
            }
        }
        
        for i in 0..<W.count {
            for j in 0..<W.count {
                if W[i][j] > 0 {
                    gs += "\(nameMap[i]) -> \(nameMap[j])[penwidth=\(normalize(value: W[i][j], from: from, to: to))]\n"
                }
            }
        }
        
        for i in 0..<clusters.count {
            let cluster = clusters[i]
            gs += "subgraph cluster_\(i) {\n"
            for nodeIndex in cluster {
                gs += "\(nameMap[nodeIndex])\n"
            }
            gs += "}\n"
        }
        gs += "}"
        do {
            try gs.write(toFile: OutPath + "modules_step_\(step).text", atomically: true, encoding: .utf8)
        } catch {
            
        }
        
    }
    
    func normalize( value:Float ,from:[Float],to:[Float] ) -> Float {
        return sqrt((to[0] * to[1] * value * value ) / (from[0] * from[1]))
    }
    
    
    func format1()  {
        for cluster in self.clusters {
            var namedC:[String] = []
            for node in cluster {
                namedC.append(self.nameMap[node])
            }
//            if (namedC.count > 1 || clusters.count < 200) {
                self.outJson1.append(namedC)
//            }
        }
        write(data: self.outJson1, to: OutPath + "modules_step_\(step).json")
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
