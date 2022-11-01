source 'https://cdn.cocoapods.org/'

# Uncomment the next line to define a global platform for your project
platform :ios, '14.1'

# Method to import the MatrixKit
def import_MatrixKit
  pod 'MatrixSDK', '~> 0.20.16'
  pod 'MatrixSDK/JingleCallStack'
end

target 'AllGram' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  # Pods for AllGram
  
  import_MatrixKit
  pod 'Reusable', '~> 4.1'
  pod 'SwiftJWT', '~> 3.6.200'
  
end

target 'AllGram Dev' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  # Pods for AllGram
  
  import_MatrixKit
  pod 'Reusable', '~> 4.1'
  pod 'SwiftJWT', '~> 3.6.200'
  
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Disable bitcode for each pod framework
      # Because the WebRTC pod (included by the JingleCallStack pod) does not support it.
      # Plus the app does not enable it
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      
      # Make fastlane(xcodebuild) happy by preventing it from building for arm64 simulator
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      
      # Force ReadMoreTextView to use Swift 5.2 version (as there is no code changes to perform)
      if target.name.include? 'ReadMoreTextView'
        config.build_settings['SWIFT_VERSION'] = '5.2'
      end
      
      # Stop Xcode 12 complaining about old IPHONEOS_DEPLOYMENT_TARGET from pods
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
    end
  end
end
