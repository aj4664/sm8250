#!/bin/bash
set -e

HOME=$(pwd)
TOOLS=$(pwd)/tools
PATCH=$(pwd)/patch
KERNEL=$(pwd)/kernel



# 构建 Linux 版本
cd $TOOLS
cd build
cmake ..
make
mv kptools kptools-linux

cd $KERNEL

make clean
make

cd $HOME

export ANDROID_NDK=/root/.android/sdk/ndk/28.0.13004108

rm -rf $PATCH/res/kpimg.enc
rm -rf $PATCH/res/kpimg


cp -r $TOOLS/build/kptools-linux $PATCH/res
cp -r $KERNEL/kpimg $PATCH/res

cd $PATCH

g++ -o encrypt encrypt.cpp -O3 -std=c++17
chmod 777 ./encrypt
./encrypt res/kpimg res/kpimg.enc
xxd -i res/kpimg.enc > include/kpimg_enc.h
xxd -i res/kptools-linux > include/kptools_linux.h


# 创建构建目录
rm -rf build-android
mkdir -p build-android
cd build-android

# 生成编译配置
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-33 \
    -DANDROID_STL=c++_static

cmake --build .

cd $PATCH
rm -rf build-linux
mkdir -p build-linux
cd build-linux
cmake .. && make
mv patch patch_linux
cp -r patch_linux $HOME