Pod::Spec.new do |s|
  s.name         = "Shallows"
  s.version      = "0.9.1"
  s.summary      = "Your lightweight persistence toolbox."
  s.description  = <<-DESC
    Shallows is a generic abstraction layer over lightweight data storage and persistence. It provides a Storage<Key, Value> type, instances of which can be easily transformed and composed with each other. It gives you an ability to create highly sophisticated, effective and reliable caching/persistence solutions.
  DESC
  s.homepage     = "https://github.com/dreymonde/Shallows"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Oleg Dreyman" => "dreymonde@me.com" }
  s.social_media_url   = "https://twitter.com/olegdreyman"
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/dreymonde/Shallows.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*"
  s.swift_version = '5.0'
  s.frameworks  = "Foundation"
end
