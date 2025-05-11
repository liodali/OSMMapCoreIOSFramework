#!/bin/bash
clear
helpFunction()
{
   echo ""
   echo "build script you should provide --version of the build"
   echo -e "\t-v --version to define version of the build and zip it"
   echo -e "\t-m destination of xcframework where will move to it"
   exit 1 # Exit script after printing help
}

copyMapCoreBundle()
{
   echo "copy bundle to framework"
   echo -e "\n"
   cp -r $1 $2/OSMFlutterFramework.framework/MapCore_MapCore.bundle
}
if [ -z "$1" ]
  then
    echo "No version supplied"
    exit 1
fi
argVersion="\ts.version = \'$1\'" #1
awk  -v version="$argVersion" 'NR==4 {$0=version} 1' OSMFlutterFramework.podspec > temp.txt && mv temp.txt OSMFlutterFramework.podspec

version=$(sed  -n 4p  OSMFlutterFramework.podspec | awk '{print $3}' | xargs)

echo " the new version : $version "
echo "================================"
echo "building for iOS (Devices/Simulator)"
echo -e "\n"

dir_config_build=$(pwd)/DerivedData
xcodebuild -workspace OSMFlutterFramework.xcworkspace -scheme OSMFlutterFramework -configuration Release -destination 'generic/platform=iOS' -destination 'generic/platform=iOS Simulator' ARCHS="arm64 x86_64"  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -UseModernBuildSystem=YES CONFIGURATION_BUILD_DIR=$dir_config_build -quiet

# Example verification step for CI
"================================"
echo -e "\n"
#version=$0
echo "retrieve build directory"

#dir_build=$(xcodebuild -project OSMFlutterFramework.xcodeproj -showBuildSettings | grep BUILD_ROOT| awk '{print $3}')
dir_build="${dir_config_build}/OSMFlutterFramework/Build/Products"
echo "dir_build=>$dir_build"
echo -e "\n"
dir_project=$(pwd)
#$(xcodebuild -project OSMFlutterFramework.xcodeproj -showBuildSettings | grep PROJECT_DIR| awk '{print $3}')
echo "dir_project=>$dir_project"
echo -e "\n"
echo "================================"
echo -e "\n"
xcframeworklocation="${dir_build}/OSMFlutterFramework.xcframework"

#cd DerivedData/OSMFlutterFramework/Build/Products
if [ -d "${dir_build}/OSMFlutterFramework.xcframework" ]
then
   echo "folder exist"
   echo -e "\n"
   echo "deleting old xcframework"
   rm -rf $xcframeworklocation
else
   echo "xcframework not found"
fi
cd $buildDir
echo -e "\n"
echo "generate xcframework"
echo -e "\n"

frameworkiphoneos="${dir_build}/Release-iphoneos/OSMFlutterFramework.framework"
frameworkiphonesimulator="${dir_build}/Release-iphonesimulator/OSMFlutterFramework.framework"

frameworkBundleiphoneos="${dir_build}/Release-iphoneos/MapCore_MapCore.bundle"
frameworkBundleiphonesimulator="${dir_build}/Release-iphonesimulator/MapCore_MapCore.bundle"

xcframeworkiphoneosBundle="${xcframeworklocation}/ios-arm64"
xcframeworkiphonesimulatorBundle="${xcframeworklocation}/ios-arm64_x86_64-simulator"
licence="${dir_project}/LICENSE"

if [ -d "$frameworkiphoneos" ] && [ -d "$frameworkiphonesimulator" ]; then
  echo "✅ Framework was correctly built at $dir_build"
else
  echo "OSMFlutterFramework Framework not found or incomplete at $dir_build"
  echo "$(ls -l $dir_build)" 
  exit 1
fi

xcodebuild -create-xcframework -framework $frameworkiphoneos -framework $frameworkiphonesimulator -output $xcframeworklocation

if [ -d "${dir_build}/OSMFlutterFramework.xcframework" ]
then
   echo "================================"
   echo -e "\n"
   echo "xcframework generated successfully"
   echo -e "\n"
   copyMapCoreBundle $frameworkBundleiphoneos  $xcframeworkiphoneosBundle
   copyMapCoreBundle $frameworkBundleiphonesimulator  $xcframeworkiphonesimulatorBundle
   if [ $# -ge 2 ]; then
      # Check if should we skip th zip
      if [ "$2" = "nozip" ]; then
         exit 0
      fi
   fi
   ziplocation="${dir_build}/OSMFlutterFramework.zip"
   if [ -d $ziplocation ]
   then
   rm -rf $ziplocation
   fi
   cp  $licence $dir_build/LICENSE
   sleep 1
   zip -r $dir_build/OSMFlutterFramework.zip $dir_build/OSMFlutterFramework.xcframework $dir_build/LICENSE --verbose
   sleep 1
   rm -rf LICENSE
   sleep 1
   if [ ! -d "${dir_build}/OSMFlutterFramework.zip" ]
   then
       echo "xcframework got not zip correclty"
       echo "build $version failed"
       exit 1
   fi
else
   echo "xcframework not generated"
   echo "build $version failed"
   exit 1
fi
echo "================================"
echo -e "\n"
echo $(pwd)
mkdir -p $dir_project/build/pod
cp -r OSMFlutterFramework.zip $dir_project/build/pod/OSMFlutterFramework-$version.zip

date
echo "build finish $1"
