Pod::Spec.new do |s|

    s.name    = 'OSMFlutterFramework'
	s.version = '0.0.2'

    s.summary           = 'Open source OSM Map use MapCore SDK'
    s.description       = 'Open source OSM Map use MapCore SDK to provide more simple APIs'
    s.homepage          = 'https://github.com/liodali/OSMMapCoreIOSFramework'
    s.license           = { :type => 'MIT', :file => 'LICENSE' }
    s.author            = 'MedAliHa'
    s.documentation_url = 'https://github.com/liodali/OSMMapCoreIOSFramework'

    s.source = {
    :http => "https://github.com/liodali/OSMMapCoreIOSFramework/releases/download/#{s.version}/OSMFlutterFramework-#{s.version}.zip"
    }

    s.platform              = :ios
    s.ios.deployment_target = '12.0'

    s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 arm64'}
    s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 arm64'}

    s.requires_arc = true

    s.vendored_frameworks = 'OSMFlutterFramework.xcframework'
    s.module_name = 'OSMFlutterFramework'

end
