#!/bin/bash
export ARCH=arm64
export SUBARCH=arm64
export PATH="${PWD}/toolchain/bin:$PATH"
export KBUILD_BUILD_VERSION="0"
a7zip="${PWD}/7zzs"

GCC32="${PWD}/toolchain/gcc32/bin"
GCC64="${PWD}/toolchain/gcc64/bin"

echo "欢迎使用NikoKernelX_sm8250_kernel构建工具"
rm -rf ${PWD}/out/*
echo "3s后开始构建kernel"
sleep 3s 

make O=out ARCH=arm64 CC=clang LLVM=1 \
LLVM_IAS=1 CLANG_TRIPLE=aarch64-linux-gnu- \
CROSS_COMPILE=$GCC64/aarch64-linux-android- \
CROSS_COMPILE_COMPAT=$GCC32/arm-linux-androideabi- \
cmi_defconfig

make -j24 O=out ARCH=arm64 CC=clang LLVM=1 \
LLVM_IAS=1 CLANG_TRIPLE=aarch64-linux-gnu- \
CROSS_COMPILE=$GCC64/aarch64-linux-android- \
CROSS_COMPILE_COMPAT=$GCC32/arm-linux-androideabi-

echo "内核构建完成,开始修补进ak3"
sleep 1s
echo "开始修补anykernel"
cp -r ${PWD}/AnyKernel3/ ${PWD}/out_ak3
mv ${PWD}/out_ak3/AnyKernel3/ ${PWD}/out_ak3/Anykernel3_cmi/
cp -rf ${PWD}/out/arch/arm64/boot/Image ${PWD}/out_ak3/Anykernel3_cmi/
sed -i 's/kernel.string=.*/kernel.string=NikoKernelX For CMI/g' ${PWD}/out_ak3/Anykernel3_cmi/anykernel.sh
sed -i "s/^device\.name1=.*/device.name1=cmi/" ${PWD}/out_ak3/Anykernel3_cmi/anykernel.sh
$a7zip a ${PWD}/out_ak3/NikoKernelX-CMI-4.19.325-SukiSU.zip ${PWD}/out_ak3/Anykernel3_cmi/*
echo "打包完成"