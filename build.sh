#!/bin/bash
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
if [ -n "$2" ]
  then
    xcodebuild -scheme OSMFlutterFramework -configuration Release -destination 'generic/platform=iOS' -destination 'generic/platform=iOS Simulator' ARCHS="arm64 x86_64"  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES PROVISIONING_PROFILE=$2

else
xcodebuild -scheme OSMFlutterFramework -configuration Release -destination 'generic/platform=iOS' -destination 'generic/platform=iOS Simulator' ARCHS="arm64 x86_64"  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
fi

echo "================================"   
echo -e "\n"
#version=$0
echo "retrieve build directory"


dir_build=$(xcodebuild -project OSMFlutterFramework.xcodeproj -showBuildSettings | grep BUILD_ROOT| awk '{print $3}')
dir_project=$(xcodebuild -project OSMFlutterFramework.xcodeproj -showBuildSettings | grep PROJECT_DIR| awk '{print $3}')
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
cd $dir_build
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

xcodebuild -create-xcframework -framework $frameworkiphoneos -framework $frameworkiphonesimulator -output $xcframeworklocation 

if [ -d "${dir_build}/OSMFlutterFramework.xcframework" ] 
then
   echo "================================"   
   echo -e "\n"
   echo "xcframework generated successfully"
   echo -e "\n"
   copyMapCoreBundle $frameworkBundleiphoneos  $xcframeworkiphoneosBundle
   copyMapCoreBundle $frameworkBundleiphonesimulator  $xcframeworkiphonesimulatorBundle
   ziplocation="${dir_build}/OSMFlutterFramework.zip"
   if [ -d $ziplocation ] 
   then
   rm -rf $ziplocation
   fi
   cp  $licence $dir_build/LICENSE
   zip -r OSMFlutterFramework.zip OSMFlutterFramework.xcframework LICENSE
   rm -rf LICENSE
else
   echo "xcframework not generated"
fi
echo "================================"   
echo -e "\n"
echo $(pwd)
mkdir -p $dir_project/build/pod
cp -r OSMFlutterFramework.zip $dir_project/build/pod/OSMFlutterFramework-$version.zip
