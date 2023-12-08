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

echo "building for iOS (Devices/Simulator)"
echo -e "\n"

xcodebuild -scheme OSMFlutterFramework -configuration Release -destination 'generic/platform=iOS' -destination 'generic/platform=iOS Simulator' ARCHS="arm64"  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

version = $0
echo "retrieve build directory"


dir_build=$(xcodebuild -project OSMFlutterFramework.xcodeproj -showBuildSettings | grep BUILD_ROOT| awk '{print $3}')

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
xcframeworkiphonesimulatorBundle="${xcframeworklocation}/ios-arm64-simulator"

xcodebuild -create-xcframework -framework $frameworkiphoneos -framework $frameworkiphonesimulator -output $xcframeworklocation

if [ -d "${dir_build}/OSMFlutterFramework.xcframework" ] 
then
   echo "xcframework generated successfully"
   echo -e "\n"
   copyMapCoreBundle $frameworkBundleiphoneos  $xcframeworkiphoneosBundle
   copyMapCoreBundle $frameworkBundleiphonesimulator  $xcframeworkiphonesimulatorBundle
   ziplocation="${dir_build}/OSMFlutterFramework.zip"
   if [ -d $ziplocation ] 
   then
   rm -rf $ziplocation
   fi
   zip -r $ziplocation $xcframeworklocation
else
   echo "xcframework not generated"
fi