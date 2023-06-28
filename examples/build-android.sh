#!/bin/bash
set -ex

# This script builds an android native-activity from go sourcecode and packages it as an apk.

# Android Studio does not need to be installed to run this script. The only prerequisite are the android-sdk
# command line tools (available as archive at https://developer.android.com/studio/index.html, see bottom of page).
# This script assumes that the command line tools are located in $HOME/android-sdk. If you wish to use
# another location set the $ANDROID_HOME environment variable accordingly. If the android-skd is already installed,
# you will likely want to call this script like this: "ANDROID_HOME=path/to/sdk path/to/this/script/build-android.sh".

# This script should be called from the folder containing the go source code, which in turn is expected to contain a folder called
# "android" with gradle files and the manifest. The native toolchain, go shared libray, assets and final apks will be copied into
# or created in this folder and it's subfolders. See the examples at (https://github.com/xlab/android-go/tree/master/examples) for
# example of the expected layout and content of the "android" folder

# Set default values if they are not provided by the environment.
: ${ANDROID_API:=34}
: ${ANDROID_HOME:=$HOME/android-sdk}
: ${ANDROID_NDK_HOME:=$ANDROID_HOME/ndk-bundle}
export ANDROID_API ANDROID_HOME ANDROID_NDK_HOME

# Install the ndk
$ANDROID_HOME/tools/bin/sdkmanager --update
$ANDROID_HOME/tools/bin/sdkmanager "ndk-bundle"

# Create native android toolchain
rm -rf android/toolchain

# $ANDROID_NDK_HOME/build/tools/make_standalone_toolchain.py --install-dir=android/toolchain --arch=arm64 --api=$ANDROID_API  --stl=libc++

# Build .so
mkdir -p android/app/src/main/jniLibs/arm64-v8a
GOOS=android GOARCH=arm64 go get -d
CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android30-clang" \
    CXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android30-clang++" \
    CGO_ENABLED=1 CGO_CFLAGS="-arch arm64" CGO_LDFLAGS="-arch arm64"\
    GOOS=android GOARCH=arm64 \
    go build -i -buildmode=c-shared -o android/app/src/main/jniLibs/arm64-v8a/libgomain.so

# Copy assets if there are any
if [ -d assets ]; then
    rm -rf android/app/src/main/assets
    cp -r assets android/app/src/main/assets
fi

# Create apk
(cd android; ./gradlew build)
cp android/app/build/outputs/apk/* android/
