
require 'json'
version = JSON.parse(File.read('package.json'))["version"]

Pod::Spec.new do |s|

  s.name         = "RNXrClient"
  s.version      = version
  s.summary      = "RNXrClient"
  s.description  = "React Native XR Client"
  s.homepage     = "https://www.magicscript.org/"
  s.license      = ""
  # s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "Magic Leap" => "author@domain.cn" }
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/magic-script/react-native-xr-client.git", :tag => "master" }
  s.source_files  = "RNXrClient/**/*.{h,m}"
  s.requires_arc = true
  s.dependency "React"
  #s.dependency "others"

end
