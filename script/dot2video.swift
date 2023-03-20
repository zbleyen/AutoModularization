#!/usr/bin/env swift
import Foundation

var lastDotF:String? = nil
var lastResizedImg: String? = nil
for step in stride(from: 1, to: 3400, by: 6) {
    do {
        var dotF = "/Users/zhangbo/Analyzer/module_result_2.26.1/tmp/modules_step_\(step)_PPSTag_allNodes.txt"
        let jpgF = "/Users/zhangbo/Desktop/graphVizImgs/img\(step / 6).jpg"
        let destJpgF = "/Users/zhangbo/Desktop/graphVizImgs/_resized/img\(step / 6).jpg"
        
        let manager = FileManager.default
        if (!manager.fileExists(atPath:dotF)) {
            print ("文件不存在")
            //copy last
            let cp = Process()
            cp.executableURL = URL(fileURLWithPath: "/bin/cp")
            cp.arguments = [lastResizedImg!,destJpgF]
            try cp.run()
            cp.waitUntilExit()
            continue
        } else {
            lastDotF = dotF
            lastResizedImg = destJpgF
        }
        
        
        let cg = Process()
        cg.executableURL = URL(fileURLWithPath: "/usr/local/bin/fdp")
        cg.arguments = ["-Tjpg",dotF,"-o",jpgF]
        try cg.run()
        cg.waitUntilExit()
        
        let convert = Process()
        convert.executableURL = URL(fileURLWithPath:"/usr/local/bin/convert")
        
        convert.arguments = ["-resize","1900x1500!",jpgF,destJpgF]
        try convert.run()
        convert.waitUntilExit()
    } catch {

    }
}

let ffmpeg = Process()
ffmpeg.executableURL = URL(fileURLWithPath:"/usr/local/bin/ffmpeg")
//ffmpeg -loop 1 -f image2 -i /Users/zhangbo/Desktop/graphVizImgs/_resized/img%d.jpg -vcodec libx264 -pix_fmt yuv420p -r 25 -t 22 test.mp4
ffmpeg.arguments = ["-loop","1","-f","image2","-i","/Users/zhangbo/Desktop/graphVizImgs/_resized/img%d.jpg","-vcodec","libx264", "-pix_fmt" ,"yuv420p", "-r", "30" ,"-t" ,"18" ,"test.mp4"]
ffmpeg.waitUntilExit()

