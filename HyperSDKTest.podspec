
Pod::Spec.new do |s|
  s.name         = "HyperSDKTest"
  s.version      = "0.0.2"
  s.summary      = "Hyper visualization and payment processing."
  s.description  = <<-DESC
                   Create payment experiences for user to improve coversion and success rate.
                   DESC

  s.homepage     = 'https://juspay.in/'
  s.license      = { :type => "LGPL", :file => "LICENSE" }
  s.author       = { "Sachin Sharma" => "sachin.sharma@juspay.in" }

  s.platform     = :ios, "12.0"
  s.resources = 'Fuse.rb'
 
  s.source       = { :git => "https://github.com/balaganesh-juspay/hyper-sdk-prerelease.git", :tag => 'v0.0.2' }

  s.dependency "JuspaySafeBrowser", "0.1.84"
  s.dependency 'Salvator', '1.0.6'
  
  s.ios.vendored_frameworks = "HyperSDK.xcframework"
end
