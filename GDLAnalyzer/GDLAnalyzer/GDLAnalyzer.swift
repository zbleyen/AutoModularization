//
//  GDLAnalyzer.swift
//  GDLAnalyzer
//
//  Created by 张博 on 2021/1/21.
//

//https://link.springer.com/chapter/10.1007/978-3-642-33718-5_31

import Foundation
import Surge

class GDLAnalyzer {
    
    let W:[[Float]]
    let N:Int
    var Nc:Int
    let Nt:Int = 50
    var clusters:[[Int]] = []
    var c2cMatrixes:[[Matrix<Float>?]] = []
    var c2cMatrixesIsZero:[[Bool?]] = []
    
    var nameList:[String]
    
    init(W:[[Float]],nameList:[String]) {
        self.W = W
        self.nameList = nameList
        self.N = W.count;
        self.Nc = self.N

        process()
    }
    
    @inline(__always)
    func matrix(start cAIndex:Int,arrawTo cBIndex:Int)  -> Matrix<Float>  {
        
        if let m = self.c2cMatrixes[cAIndex][cBIndex] {
            return m
        }
        let A = self.clusters[cAIndex]
        let B = self.clusters[cBIndex]
        var w:[[Float]] = []
        var allZero = true
        for i in A {
            var newRow:[Float] = []
            for j in B {
                let w = self.W[i][j]
                allZero = allZero && w == 0
                newRow.append(w)
            }
            w.append(newRow)
        }
        let m = Matrix(w)
        if (!allZero) { //优化 全0矩阵没必要缓存
            self.c2cMatrixes[cAIndex][cBIndex] = m
        }
        self.c2cMatrixesIsZero[cAIndex][cBIndex] = allZero
        return m
    }
    
    func updateMatrixesCacheWithMerge(cAIndex:Int ,cBIndex:Int )  {
        let mcN = self.c2cMatrixes.count
        
        //较小值的索引对应的cluster因为替换了，所以需要重新计算Matrix
        self.c2cMatrixes[cAIndex] = Array(repeating: nil, count: mcN)
        for i in 0..<mcN {
            var row = self.c2cMatrixes[i]
            row[cAIndex] = nil
            self.c2cMatrixes[i] = row
        }
        
        //较大值的索引对应的cluster因为删除了，所以删除对应行和对应列
        self.c2cMatrixes.remove(at: cBIndex)
        for i in 0..<mcN-1 {    //因为刚删除了一行
            var row = self.c2cMatrixes[i]
            row.remove(at: cBIndex)
            self.c2cMatrixes[i] = row
        }
        
        
        
        //较小值的索引对应的cluster因为替换了，所以需要重新计算Matrix
        self.c2cMatrixesIsZero[cAIndex] = Array(repeating: nil, count: mcN)
        for i in 0..<mcN {
            var row = self.c2cMatrixesIsZero[i]
            row[cAIndex] = nil
            self.c2cMatrixesIsZero[i] = row
        }
        
        //较大值的索引对应的cluster因为删除了，所以删除对应行和对应列
        self.c2cMatrixesIsZero.remove(at: cBIndex)
        for i in 0..<mcN-1 {    //因为刚删除了一行
            var row = self.c2cMatrixesIsZero[i]
            row.remove(at: cBIndex)
            self.c2cMatrixesIsZero[i] = row
        }
    }
    
@inline(__always)
    func affinity(cAIndex:Int,cBIndex:Int) -> Float {
        //优化
        if let a2bAllZero = self.c2cMatrixesIsZero[cAIndex][cBIndex] {
            if let b2aAllZero = self.c2cMatrixesIsZero[cBIndex][cAIndex] {
                if (a2bAllZero || b2aAllZero) {
                    return 0
                }
            }
        }
        
        let cA = self.clusters[cAIndex]
        let cB = self.clusters[cBIndex]
        let cAN = cA.count
        let cBN = cB.count
        
        let a2bM = matrix(start: cAIndex, arrawTo: cBIndex)
        let b2aM = matrix(start: cBIndex, arrawTo: cAIndex)
        
        let leftPart:Vector<Float> = Vector(Array(repeating: 1, count: cAN)) * a2bM * b2aM  //这里少乘一个所有元素为1，长度为cBN 的列向量，取相加代替
        var affleft:Float = 0
        for a in leftPart.scalars {
            affleft += a
        }
        affleft /= Float(cAN * cAN)
        
        var affRight:Float = 0
        let rightPart:Vector<Float> = Vector(Array(repeating: 1, count: cBN)) * b2aM * a2bM //这里少乘一个所有元素为1，长度为cAN 的列向量，取相加代替
        for a in rightPart.scalars {
            affRight += a
        }
        affRight /= Float(cBN * cBN)
        
        return affleft + affRight
    }
    
    func preprocess() {
        for i in (0..<N) {
            self.clusters.append([i])
        }
        for _ in (0..<N) {
            self.c2cMatrixes.append(Array(repeating: nil, count: N))
            self.c2cMatrixesIsZero.append(Array(repeating: nil, count: N))
        }
    }
    
    func process() {
        preprocess()
        gdl_loop();
    }
    
    func gdl_loop() {
        while Nc > Nt {
            if (gdl_loop_step() == 0) {
                break
            }
            Nc -= 1
            Output(clusers:self.clusters , nameMap:self.nameList,step: N - Nc)
        }
    }
    
    func gdl_loop_step() -> Float{
        let Nc = self.clusters.count
        var maxAffinity:Float = 0
        var recordAIndex = 0
        var recardBIndex = 0
        if (Nc <= 2) {
            return 0
        }
        for cAIndex in 0..<(Nc - 1) {
            for cBIndex in (cAIndex + 1)..<Nc {
                let thisAffinity = affinity(cAIndex: cAIndex, cBIndex: cBIndex)
                if (thisAffinity > maxAffinity) {
                    maxAffinity = thisAffinity
                    recordAIndex = cAIndex
                    recardBIndex = cBIndex
                }
            }
        }
        if (maxAffinity > 0) {
            let leftIndex = min(recordAIndex, recardBIndex)
            let rightIndex = max(recordAIndex, recardBIndex)
            updateMatrixesCacheWithMerge(cAIndex: leftIndex, cBIndex: rightIndex)
            var cNew = (self.clusters[leftIndex] + self.clusters[rightIndex])
            cNew.sort()
            self.clusters.remove(at: rightIndex)
            self.clusters[leftIndex] = cNew
            
        }
        return maxAffinity;
    }
    
    
    
}
