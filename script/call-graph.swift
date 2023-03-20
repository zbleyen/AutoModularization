#!/usr/bin/env swift
import Foundation

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    return output
}

// Example usage:
shell("rm -rf /tmp/call-graph/Analyzer/*")
shell("mkdir -p /tmp/call-graph/Analyzer/")
shell("mkdir -p /tmp/call-graph/Analyzer/dotFile/")
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
for compileIem in dic {
    let cg = Process()
    cg.executableURL = URL(fileURLWithPath: "./call-graph")
    cg.arguments = [compileIem["directory"]!+"/"+compileIem["file"]!]
    try cg.run()
    cg.waitUntilExit()
//    print(compileIem["directory"]!+"/"+compileIem["file"]!)
}

