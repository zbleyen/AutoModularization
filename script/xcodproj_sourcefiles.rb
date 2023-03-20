#!/usr/bin/ruby
require 'xcodeproj'
require 'find'

def getSourceFiles(projFile)
    project = Xcodeproj::Project.open(projFile)
    target = project.targets.first
    files = target.source_build_phase.files.to_a.map do |pbx_build_file|
        tmpPath = pbx_build_file.file_ref.real_path.to_s
    
        puts pbx_build_file.file_ref.display_name.to_s

    end
    project.save
end

projFile = ARGV[0]
proj_file_paths = []
Find.find(projFile) do |path|
    proj_file_paths << path if path =~ /.*\.xcodeproj$/
end
if (proj_file_paths.size > 0)
    getSourceFiles(proj_file_paths[0])
end



