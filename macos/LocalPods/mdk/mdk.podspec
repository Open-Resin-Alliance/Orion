Pod::Spec.new do |s|
  s.name             = 'mdk'
  s.version          = '0.35.0'
  s.summary          = 'Multimedia Development Kit'
  s.homepage         = 'https://github.com/wang-bin/mdk-sdk'
  s.license          = { :type => 'Commercial' }
  s.author           = { 'Wang Bin' => 'wbsecg1@gmail.com' }
  
  # Use the stable apple SDK from GitHub releases instead of broken SourceForge nightly
  s.source           = { :http => 'https://github.com/wang-bin/mdk-sdk/releases/download/v0.35.0/mdk-sdk-apple.tar.xz' }
  
  s.osx.deployment_target = '10.13'
  
  s.vendored_frameworks = 'mdk-sdk/lib/mdk.xcframework'
  
  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=*simulator*]' => 'i386'
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=*simulator*]' => 'i386'
  }
end
