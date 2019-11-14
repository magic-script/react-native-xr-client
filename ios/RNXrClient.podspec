
require 'json'

package = JSON.parse(File.read(File.join(__dir__, '../package.json')))

Pod::Spec.new do |s|

  s.name         = "RNXrClient"
  s.version      = package['version']
  s.summary      = package['description']
  s.description  = package['description']
  s.license      = package['license']
  s.author       = package['author']
  s.homepage     = package['homepage']
  s.source       = { :git => "https://github.com/magic-script/react-native-xr-client.git", :tag => "remove-external-folder" }

  s.platform     = :ios, "12.0"
  s.requires_arc = true

  s.preserve_paths = 'README.md', 'package.json', 'index.js'
  s.source_files  = ["src/*.{h,m,swift}"]
  s.framework  = "MLXR"
  s.dependency "React"
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

end
