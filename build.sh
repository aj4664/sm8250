#!/bin/bash

source ../settings.sh

#
#   settings.sh (example)
#
# export VERSION="1.x.x"
# export BUILD=1
# export PREFIX="e"
# export DESC="description"
# export DEVICE="alioth"
# export TGTOKEN=bot_id
# export LAST=last commit hash for generation changelog
# export TYPE="test or early"
# export LEVEL=1
# export EXTRA=""
#

START=$(date +%s)

rm -rf out

MAIN=/home/timisong

KERNEL=$PWD

CLANG=$MAIN/clang
GCC_ARM=$MAIN/arm-linux-androideabi-4.9
GCC_AARCH64=$MAIN/aarch64-linux-android-4.9

check_and_clone() {
    local dir=$1
    local repo=$2
    local name=$3

    if [ ! -d $dir ]; then
        echo Папка $dir не существует. Клонирование $repo
        cd $dir
        git clone $repo $name
    fi
}

check_and_wget() {
    local dir=$1
    local repo=$2

    if [ ! -d $dir ]; then
        echo Папка $dir не существует. Клонирование $repo
        mkdir $dir
        cd $dir
        wget -O clang.tar.gz $repo
        tar -zxvf clang.tar.gz
        rm -rf clang.tar.gz
        cd ../kernel_xiaomi_sm8250
    fi
}

build() {
    git log $LAST..HEAD > ../changelog.txt
    BRANCH=$(git branch --show-current)

    MAGICTIME=$KERNEL/MagicTime-$DEVICE

    if [ ! -d $MAGICTIME ]; then
        mkdir -p $MAGICTIME

        if [ ! -d $MAGICTIME/Anykernel ]; then
            git clone https://github.com/TIMISONG-dev/Anykernel.git \
                $MAGICTIME/Anykernel

            mv $MAGICTIME/Anykernel/* $MAGICTIME/

            rm -rf $MAGICTIME/Anykernel
        fi
    else
        if [ -d $MAGICTIME/.git ]; then
            rm -rf $MAGICTIME/.git
        fi
    fi

    if [ $DEVICE = pipa ]; then
        IMG=$MAGICTIME/kernels/Image
        DTB=$MAGICTIME/kernels/dtb
        DTBO=$MAGICTIME/kernels/dtbo.img
    else
        IMG=$MAGICTIME/Image
        DTB=$MAGICTIME/dtb
        DTBO=$MAGICTIME/dtbo.img
    fi

    make O="$OUT" \
            ${DEVICE}_defconfig \
            vendor/xiaomi/magictime-common.config

    # Компиляция ядра
    make -j $(nproc) \
                O="$OUT" \
                CC="ccache clang" \
                HOSTCC=gcc \
                LD=ld.lld \
                AS=llvm-as \
                AR=llvm-ar \
                NM=llvm-nm \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip \
                LLVM=1 \
                LLVM_IAS=1 \
                V=$VERBOSE 2>&1 | tee build.log

find $DTS -name '*.dtb' -exec cat {} + > $DTB
find $DTS -name 'Image' -exec cat {} + > $IMG
find $DTS -name 'dtbo.img' -exec cat {} + > $DTBO

END=$(date +%s)
ELAPSED=$((END - START))

if grep -q -E "Ошибка 2|Error 2" build.log; then
    echo Ошибка: Сборка завершилась с ошибкой

    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendMessage \
    -d chat_id=@magictimekernel \
    -d text="Ошибка в компиляции!" \
    -d message_thread_id=38153

    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=@magictimekernel \
    -F document=@./build.log \
    -F message_thread_id=38153

    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=@magictimekernel \
    -F document=@../changelog.txt \
    -F message_thread_id=38153
else
    echo Общее время выполнения: $ELAPSED секунд

    cd $MAGICTIME
    7z a -mx9 MagicTime-$DEVICE-$BUILD_DATE.zip * -x!*.zip
    
    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendMessage \
    -d chat_id=@magictimekernel \
    -d text="Компиляция завершилась успешно! Время выполнения: $ELAPSED секунд" \
    -d message_thread_id=38153

    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=@magictimekernel \
    -F document=@./MagicTime-$DEVICE-$BUILD_DATE.zip \
    -F caption="MagicTime ${VERSION}${PREFIX}${BUILD} (${DESC}) branch: ${BRANCH}" \
    -F message_thread_id=38153
    
    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=@magictimekernel \
    -F document=@../changelog.txt \
    -F caption="Latest changes" \
    -F message_thread_id=38153

    rm -rf MagicTime-$DEVICE-$BUILD_DATE.zip

    BUILD=$((BUILD + 1))

    cd $KERNEL
    LAST=$(git log -1 --format=%H)

    sed -i "s/LAST=.*/LAST=$LAST/" ../settings.sh
    sed -i "s/BUILD=.*/BUILD=$BUILD/" ../settings.sh
fi
}

check_and_wget $CLANG \
    https://github.com/ZyCromerZ/Clang/releases/download/22.0.0git-20250805-release/Clang-22.0.0git-20250805.tar.gz
check_and_clone $GCC_ARM \
    https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 \
        arm-linux-androideabi-4.9
check_and_clone $GCC_AARCH64 \
    https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 \
        aarch64-linux-android-4.9

export PATH=$CLANG/bin:$GCC_AARCH64/bin:$GCC_ARM/bin:$PATH
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export KBUILD_BUILD_USER=TIMISONG
export KBUILD_BUILD_HOST=timisong-dev

BUILD_DATE=$(date '+%Y-%m-%d_%H-%M-%S')

OUT=out

if [ $LEVEL = 1 ] && [ $TYPE = test ]; then
    DEVICE="alioth"
    DESC="POCO F3 build"
    build
    LEVEL=$((LEVEL + 1))
    sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
    clear
fi

if [ $LEVEL = 1 ] && [ $TYPE = early ]; then
    build
    clear
fi

if [ $TYPE = test ]; then
    if [ $LEVEL = 2 ]; then
        DEVICE="pipa"
        DESC="Mi Pad 6 AOSP build"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
    fi

    if [ $LEVEL = 3 ]; then
        DEVICE="alioth"
        git cherry-pick 6180281005f4a2ce7ea4895d1e35be47f99b3e11
        DESC="POCO F3 build 5k battery"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
        git reset --hard HEAD~1
    fi

    if [ $LEVEL = 4 ]; then
        git revert 48d6466f502f0ed1ecafbad71aac79ec64f60cd8 --no-edit
        git cherry-pick 2897f115faac5228433002d380ab0176ba825c95
        git revert a3f0009c637419795baf4195c4b236aa4c23a00a --no-edit
        DESC="POCO F3 build without susfs"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
    fi

    if [ $LEVEL = 5 ]; then
        if [ $EXTRA = "!4"]; then
            git revert 48d6466f502f0ed1ecafbad71aac79ec64f60cd8 --no-edit
            git cherry-pick 2897f115faac5228433002d380ab0176ba825c95
            git revert a3f0009c637419795baf4195c4b236aa4c23a00a --no-edit
        fi
        DEVICE="pipa"
        DESC="Mi Pad 6 AOSP build without susfs"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
    fi

    if [ $LEVEL = 6 ]; then
        if [ $EXTRA = "!4"]; then
            git revert 48d6466f502f0ed1ecafbad71aac79ec64f60cd8 --no-edit
            git cherry-pick 2897f115faac5228433002d380ab0176ba825c95
            git revert a3f0009c637419795baf4195c4b236aa4c23a00a --no-edit
        fi
        DEVICE="alioth"
        git cherry-pick 6180281005f4a2ce7ea4895d1e35be47f99b3e11
        DESC="POCO F3 build 5k battery without susfs"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear

        git reset --hard HEAD~4
        clear
    fi

    # MIUI

    git checkout magictime-miui

    if [ $LEVEL = 7 ]; then
        DESC="POCO F3 MIUI build"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
    fi

    if [ $LEVEL = 8 ]; then
        DEVICE="pipa"
        DESC="Mi Pad 6 MIUI build"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
    fi

    if [ $LEVEL = 9 ]; then
        DEVICE="alioth"
        git cherry-pick 6180281005f4a2ce7ea4895d1e35be47f99b3e11
        DESC="POCO F3 MIUI build 5k battery"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
        git reset --hard HEAD~1
    fi

    if [ $LEVEL = 10 ]; then
        git revert 48d6466f502f0ed1ecafbad71aac79ec64f60cd8 --no-edit
        git cherry-pick 2897f115faac5228433002d380ab0176ba825c95
        git revert a3f0009c637419795baf4195c4b236aa4c23a00a --no-edit
        DESC="POCO F3 MIUI build without susfs"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
    fi

    if [ $LEVEL = 11 ]; then
        if [ $EXTRA = "!10" ]; then
            git revert 48d6466f502f0ed1ecafbad71aac79ec64f60cd8 --no-edit
            git cherry-pick 2897f115faac5228433002d380ab0176ba825c95
            git revert a3f0009c637419795baf4195c4b236aa4c23a00a --no-edit
        fi
        DEVICE="pipa"
        DESC="Mi Pad 6 MIUI build without susfs"
        build
        LEVEL=$((LEVEL + 1))
        sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
        clear
    fi

    if [ $LEVEL = 12 ]; then
        if [ $EXTRA = "!10" ]; then
            git revert 48d6466f502f0ed1ecafbad71aac79ec64f60cd8 --no-edit
            git cherry-pick 2897f115faac5228433002d380ab0176ba825c95
            git revert a3f0009c637419795baf4195c4b236aa4c23a00a --no-edit
        fi
        DEVICE="alioth"
        git cherry-pick 6180281005f4a2ce7ea4895d1e35be47f99b3e11
        DESC="POCO F3 MIUI build 5k battery without susfs"
        build

        git reset --hard HEAD~4
        clear
    fi

    LEVEL=1
    EXTRA=""
    sed -i "s/LEVEL=.*/LEVEL=$LEVEL/" ../settings.sh
    sed -i "s/EXTRA=.*/EXTRA=$EXTRA/" ../settings.sh
    git checkout magictime-new
    clear
fi
