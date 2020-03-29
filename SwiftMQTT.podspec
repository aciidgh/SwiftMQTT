
Pod::Spec.new do |s|
    
    s.name         = "SwiftMQTT"
    s.version      = "3.0.1"
    s.summary      = "MQTT Client in pure Swift"
    s.description  = <<-DESC
    MQTT Client in Swift 4.1 based on MQTT Version 3.1.1
    DESC
    
    s.homepage     = "https://github.com/aciidb0mb3r/SwiftMQTT"
    s.license      = { :type => "MIT", :file => "LICENSE" }
    s.author       = { "Ankit Agarwal" => "ankit.spd@gmail.com" }
    s.source       = { :git => "https://github.com/aciidb0mb3r/SwiftMQTT.git", :tag => s.version.to_s }
    
    s.swift_version = "4.1"

    s.ios.deployment_target = "8.0"
    s.osx.deployment_target = "10.10"
    s.tvos.deployment_target = "9.0"

    s.source_files  = "SwiftMQTT/SwiftMQTT/**/*.swift"

    s.frameworks  = "Foundation"
    
end
