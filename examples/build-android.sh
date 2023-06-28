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
# example of the expected layout and content of the "android" folder.

# The ANDROID_ARCH, ANDROIND_ARCH_ABI, and ANDROID_GOARCH variables determine for what platform the libraries are built. 
# To build for multiple platforms, run this script once for each platform with the appropriate values for those variables. 
# Then set all of those platforms as abiFilters in app/build.gradle and build the app again.

# Set default values if they are not provided by the environment.
: ${ANDROID_API:=34}
: ${ANDROID_TOOLCHAIN:=30}
: ${ANDROID_HOME:=$HOME/android-sdk}
: ${ANDROID_NDK_HOME:=$ANDROID_HOME/ndk-bundle}
: ${ANDROID_ARCH:=aarch64}
: ${ANDROID_ARCH_ABI:=arm64-v8a}
: ${ANDROID_GOARCH:=arm64}
export ANDROID_API ANDROID_TOOLCHAIN ANDROID_HOME ANDROID_NDK_HOME ANDROID_ARCH ANDROID_ARCH_ABI ANDROID_GOARCH

# Install the ndk
# Windows Git Bash
if [[ "$OSTYPE" == "msys" ]]; then
    : ${OSNAME:="windows"}
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager.bat --update
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager.bat "ndk-bundle"
# Everything else (linux, macOS, etc)
else
    : ${OSNAME:=$OSTYPE}
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --update
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "ndk-bundle"
fi


# # Create native android toolchain
# rm -rf android/toolchain

# $ANDROID_NDK_HOME/build/tools/make_standalone_toolchain.py --install-dir=android/toolchain --arch=arm64 --api=$ANDROID_API  --stl=libc++

USE_CGO_FLAGS=""
if [[ "$ANDROID_GOARCH" == "arm64" ]]; then
    USE_CGO_FLAGS="-arch arm64"
fi

# Build .so
mkdir -p android/app/src/main/jniLibs/$ANDROID_ARCH_ABI
GOOS=android GOARCH=$ANDROID_GOARCH go get -d
CC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$OSNAME-x86_64/bin/$ANDROID_ARCH-linux-android$ANDROID_TOOLCHAIN-clang" \
    CXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$OSNAME-x86_64/bin/$ANDROID_ARCH-linux-android$ANDROID_TOOLCHAIN-clang++" \
    CGO_ENABLED=1 CGO_CFLAGS=$USE_CGO_FLAGS CGO_LDFLAGS=$USE_CGO_FLAGS \
    GOOS=android GOARCH=$ANDROID_GOARCH \
    go build -i -buildmode=c-shared -o android/app/src/main/jniLibs/$ANDROID_ARCH_ABI/libgomain.so

# Copy assets if there are any
if [ -d assets ]; then
    rm -rf android/app/src/main/assets
    cp -r assets android/app/src/main/assets
fi

# Create apk
(cd android; ./gradlew build)
cp android/app/build/outputs/apk/* android/
