#!/usr/bin/env bash

echo "post build script was executed"

cd /Users/runner/Library/Developer/Xcode/DerivedData/E2EApp-*/Build/Intermediates.noindex/ArchiveIntermediates/E2EApp/BuildProductsPath/Release-iphoneos

BUILD_PATH=$(pwd)

echo $BUILD_PATH

ls -R $BUILD_PATH

appcenter test run xcuitest \
--app "ashley.arthur-vonage.com/IOS-SDK_TEST" \
--devices "ashley.arthur-vonage.com/ios11" \
--test-series "master" \
--locale "en_US" \
--token "1b2050ed79bfa481249056ef0970e19938771312" \
--build-dir $BUILD_PATH