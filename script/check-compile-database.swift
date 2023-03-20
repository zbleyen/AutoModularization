#!/usr/bin/env swift
import Foundation


let compileDatabaseFile = "compile_commands.json";
var filePath:String = ""
if (CommandLine.argc >= 2) {
    filePath = CommandLine.arguments[1]
} else {
    print("输入compile_commands.json文件路径")
    exit(1)
}

var jsonData = try Data(contentsOf: URL(fileURLWithPath: filePath).appendingPathComponent(compileDatabaseFile))
let dic = try JSONDecoder().decode(Array<Dictionary<String, String>>.self, from: jsonData);
var index = 0
var filterdJsonData:Array<Dictionary<String, String>> = []
var begin = false
for compileIem in dic {
    let cg = Process()
//    cg.executableURL = URL(fileURLWithPath: "/Users/zhangbo/clang-llvm/build/bin/call-graph")
//    cg.arguments = [compileIem["directory"]!+"/"+compileIem["file"]!]
//    try cg.run()
//    cg.waitUntilExit()
    let compileFilePath = compileIem["directory"]!+"/"+compileIem["file"]!
    
    
//    if (compileFilePath.hasSuffix("QPYouthMineVC.m")) {
        begin = true
        
//    }
    if (!begin) {
        continue
    }
//    print(compileIem["command"])
    var command = compileIem["command"]!
    var compileIem = compileIem
    
    compileIem["command"] = command.replacingOccurrences(of: " -gmodules", with: "")
    command = command.replacingOccurrences(of: "-isystem /Users/developer/Workspace/PPS/Pods/freetype/**/*.{h,c}", with: "")
    filterdJsonData.append(compileIem)

    
}
let filterdData = try JSONEncoder().encode(filterdJsonData)
try filterdData.write(to: URL(fileURLWithPath: filePath).appendingPathComponent("compile_commands.json"))

