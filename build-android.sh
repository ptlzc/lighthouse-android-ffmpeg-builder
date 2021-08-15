#!/bin/sh

# 配置NDK路径，根据本机环境自己指定
ANDROID_NDK_ROOT=/android/android-ndk-r21d
# ABI版本，自己指定
ABI_VERSION=28

if [ ! -d "./ffmpeg" ]; then
  git clone git@github.com:FFmpeg/FFmpeg.git ffmpeg
  git checkout git checkout release/4.4
fi

# 设置编译文件后输出文件夹
OUTPUT=$(pwd)/build
# 清空输出文件夹
rm -rf "$OUTPUT"
# 新建输出文件夹
mkdir -p "$OUTPUT"

cd ffmpeg

# 交叉工具链的路径
TOOLCHAIN=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64

# ffmpeg配置
COMMON_SET="
  --enable-cross-compile \
  --target-os=android \
  --enable-small \
  --sysroot=$TOOLCHAIN/sysroot \
  --extra-cflags="-fpic" \
  --disable-shared \
  --enable-static \
  --disable-symver \
  --disable-doc \
  --disable-htmlpages \
  --disable-manpages \
  --disable-podpages \
  --disable-txtpages \
  --disable-ffplay \
  --disable-ffmpeg \
  --disable-ffprobe \
  --disable-avdevice \
  --disable-bsfs \
  --disable-devices \
  --disable-protocols \
  --enable-protocol=file \
  --disable-protocol=rtmp* \
  --disable-protocol=rtmp \
  --disable-protocol=rtmpt \
  --disable-protocol=rtp \
  --disable-protocol=sctp \
  --disable-protocol=srtp \
  --disable-parsers \
  --disable-demuxers \
  --enable-demuxer=mov \
  --enable-demuxer=mp3 \
  --enable-demuxer=image2 \
  --enable-demuxer=gif \
  --enable-demuxer=wav \
  --enable-demuxer=flv \
  --enable-demuxer=live_flv \
  --enable-demuxer=data \
  --enable-demuxer=mpegps \
  --enable-demuxer=mpegts \
  --enable-demuxer=hls \
  --disable-decoders \
  --enable-decoder=aac \
  --enable-decoder=png \
  --enable-decoder=h264 \
  --enable-decoder=mp3 \
  --enable-decoder=mjpeg \
  --enable-decoder=mpeg4 \
  --enable-decoder=gif \
  --enable-decoder=pcm_s16le \
  --enable-decoder=hevc \
  --disable-muxers \
  --disable-encoders \
  --enable-swscale \
  --disable-filters \
  --enable-filter=crop \
  --enable-filter=scale \
  --enable-filter=afade \
  --enable-filter=atempo \
  --enable-filter=copy \
  --enable-filter=aformat \
  --enable-filter=overlay \
  --enable-filter=vflip \
  --enable-filter=hflip \
  --enable-filter=transpose \
  --enable-filter=volume \
  --enable-filter=rotate \
  --enable-filter=apad \
  --enable-filter=amerge \
  --enable-filter=aresample \
  --enable-filter=setpts \
  --enable-filter=fps \
  --enable-filter=palettegen \
  --enable-filter=paletteuse \
  --enable-filter=trim \
  --enable-filter=null \
  --enable-filter=overlay \
  --enable-filter=format \
  --enable-filter=atrim \
  --enable-filter=split \
  --enable-filter=amix \
  --enable-filter=anull \
  --enable-filter=adelay \
  --enable-gpl \
  --enable-zlib \
  --enable-jni \
  --enable-mediacodec \
  --enable-decoder=h264_mediacodec \
  --enable-decoder=mpeg4_mediacodec \
  --enable-decoder=vp9_mediacodec \
  --enable-decoder=vp8_mediacodec \
  --enable-decoder=hevc_mediacodec \
  --enable-hwaccels \
  --enable-asm \
  --enable-version3 "

# 配置configure并编译
build64(){
    ARCH=aarch64
    ARCH_FLAGS="\
    --arch=$ARCH \
    --cross-prefix=$TOOLCHAIN/bin/aarch64-linux-android- \
    --cc=$TOOLCHAIN/bin/aarch64-linux-android$ABI_VERSION-clang \
    --prefix=$OUTPUT/aarch64 \
    "
    ARCH_OUTPUT="$OUTPUT/$ARCH/lib"
    rm -rf "$ARCH_OUTPUT"
    mkdir -p "$ARCH_OUTPUT"
    ./configure \
    ${COMMON_SET} \
    ${ARCH_FLAGS}

    make clean all
    make -j$(nproc) 
    make install
}

# 打包为单文件
package64(){
    ARCH=aarch64
    ARCH_OUTPUT="$OUTPUT/$ARCH/lib"
    GCC_L=$ANDROID_NDK_ROOT/toolchains/$ARCH-linux-android-4.9/prebuilt/linux-x86_64/lib/gcc/$ARCH-linux-android/4.9.x
    SYSROOT_L=$TOOLCHAIN/sysroot/usr/lib/$ARCH-linux-android
    $TOOLCHAIN/bin/$ARCH-linux-android-ld -L$ARCH_OUTPUT -L$GCC_L \
        -rpath-link=$SYSROOT_L/$ABI_VERSION -L$SYSROOT_L/$ABI_VERSION -soname libffmpeg.so \
        -shared -nostdlib -Bsymbolic --whole-archive --no-undefined -o $ARCH_OUTPUT/libffmpeg.so \
        -lavcodec -lpostproc -lavfilter -lswresample -lavformat -lavutil -lswscale -lgcc \
    -lc -ldl -lm -lz -llog \
    --dynamic-linker=/system/bin/linker

}


# 编译32位
build32() {
    ARCH=armv7a
    ARCH_FLAGS="\
    --arch=$ARCH \
    --cross-prefix=$TOOLCHAIN/bin/arm-linux-androideabi- \
    --cc=$TOOLCHAIN/bin/armv7a-linux-androideabi$ABI_VERSION-clang \
    --cxx=$TOOLCHAIN/bin/armv7a-linux-androideabi$ABI_VERSION-clang++ \
    --prefix=$OUTPUT/$ARCH \
    "
    ARCH_OUTPUT="$OUTPUT/$ARCH/lib"
    rm -rf "$ARCH_OUTPUT"
    mkdir -p "$ARCH_OUTPUT"

  ./configure \
  ${COMMON_SET} \
  ${ARCH_FLAGS}

  make clean all
  make -j$(nproc) 
  make install

}


# 打包32位单文件
package32() {
  ARCH=armv7a
  ARCH_OUTPUT="$OUTPUT/$ARCH/lib"

  GCC_L=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/lib/gcc/arm-linux-androideabi/4.9.x/armv7-a/thumb
  SYSROOT_L=$TOOLCHAIN/sysroot/usr/lib/arm-linux-androideabi

  $TOOLCHAIN/bin/arm-linux-androideabi-ld -L$ARCH_OUTPUT -L$GCC_L \
    -rpath-link=$SYSROOT_L/$ABI_VERSION -L$SYSROOT_L/$ABI_VERSION -soname libffmpeg.so \
    -shared -nostdlib -Bsymbolic --whole-archive --no-undefined -o $ARCH_OUTPUT/libffmpeg.so \
    -lavcodec -lpostproc -lavfilter -lswresample -lavformat -lavutil -lswscale -lgcc \
  -lc -ldl -lm -lz -llog \
  --dynamic-linker=/system/bin/linker

}


build64

package64

build32

package32