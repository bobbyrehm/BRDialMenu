Pod::Spec.new do |s|
  s.name         = "BRDialMenu"
  s.version      = "1.0"
  s.summary      = "Dial Menu Control for iOS"
  s.license      = 'MIT'
  s.author       = { "Bobby Rehm" => "bobbyrehm@autolean.com" }
  s.source       = { :git => "https://github.com/bobbyrehm/BRDialMenu.git", :tag => "1.0" }
  s.source_files = 'BRDialMenu/BRDialMenu.swift'
  s.resources    = 'BRDialMenu/BRDialMenu.swift'
  s.requires_arc = true
  s.platform     = :ios , '10.0'
end
