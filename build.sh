#!/bin/bash

TANGGAL=$(date +"%F-%S")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
NAME_KERNEL_FILE="$1"
chat_id="$(grep tg_chat $NAME_KERNEL_FILE | cut -f2 -d"=" )"
token="6135461084:AAEH5rfzSv8vyANuGDb5MQM18vqHi3Dbvsg"

#INFROMATION NAME KERNEL
export KBUILD_BUILD_USER=$(grep kbuild_user $NAME_KERNEL_FILE | cut -f2 -d"=" )
export KBUILD_BUILD_HOST=$(grep kbuild_host $NAME_KERNEL_FILE | cut -f2 -d"=" )
export LOCALVERSION=$(grep local_version $NAME_KERNEL_FILE | cut -f2 -d"=" )
NAME_KERNEL=$(grep name_zip $NAME_KERNEL_FILE | cut -f2 -d"=" )
VENDOR_NAME=$(grep vendor_name $NAME_KERNEL_FILE | cut -f2 -d"=" )
DEVICE_NAME=$(grep device_name $NAME_KERNEL_FILE | cut -f2 -d"=" )
DEFCONFIG_NAME=$(grep defconfig_name $NAME_KERNEL_FILE | cut -f2 -d"=" )
DEFCONFIG_FLAG=$(grep defconfig_flag $NAME_KERNEL_FILE | cut -f2 -d"=" )

#INFORMATION GATHER LINK
LINK_KERNEL=$(grep link_kernel $NAME_KERNEL_FILE | cut -f2 -d"=" )
LINK_CLANG=$(grep link_clang $NAME_KERNEL_FILE | cut -f2 -d"=" )
LINK_anykernel=$(grep link_anykernel $NAME_KERNEL_FILE | cut -f2 -d"=" )

initial_kernel() {
   git clone --depth=1 --recurse-submodules -j8 --single-branch $LINK_KERNEL ~/kernel
   cd ~/kernel
}

clone_git() {
  cd ~/kernel
  # download toolchains
  git clone --depth=1 $LINK_anykernel ~/AnyKernel

   # download toolchains
  git clone --depth=1 $LINK_CLANG clang
}

cleaning_cache() {
  cd ~/kernel
  if [ -f ~/log_build.txt ]; then
    rm -rf ~/log_build.txt
  fi
  if [ -d out ]; then
    rm -rf out
  fi
  if [ -d HASIL ]; then
    rm -rf HASIL/**
  fi
  if [ -d ~/AnyKernel ]; then
    rm -rf ~/AnyKernel
  fi
}

sticker() {
  curl -s -X POST "https://api.telegram.org/bot$token/sendSticker" \
    -d sticker="CAACAgEAAxkBAAEnKnJfZOFzBnwC3cPwiirjZdgTMBMLRAACugEAAkVfBy-aN927wS5blhsE" \
    -d chat_id=$chat_id
}

sendinfo() {
  cd ~/kernel
  curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
    -d chat_id="$chat_id" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="
                    <b>$NAME_KERNEL</b>
Build started on <code>CirrusCI</code>
For device ${DEVICE_NAME}
Build By <b>$KBUILD_BUILD_USER</b>
USING DEFCONFIG <b>$DEFCONFIG_NAME</b>
branch <code>$(git rev-parse --abbrev-ref HEAD)</code> (master)
Under commit <code>$(git log --pretty=format:'"%h : %s"' -1)</code>
Using compiler: <code>$(~/kernel/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/ */ /g')</code>
Started on <code>$(date)</code>
<b>Build Status:</b> Beta"
}

push() {
  cd ~/AnyKernel
  sha512_hash="$(sha512sum ${NAME_KERNEL}-*.zip | cut -f1 -d ' ')"
  ZIP1=$(echo ${NAME_KERNEL}-*.zip)
  mv ~/log_build.txt .
  ZIP2=log_build.txt
  minutes=$(($DIFF / 60))
  seconds=$(($DIFF % 60))
  curl -F document=@$ZIP1 "https://api.telegram.org/bot$token/sendDocument" \
    -F chat_id="$chat_id" \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="
                          Build took ${minutes} minute(s) and ${seconds} second(s).
For ${DEVICE_NAME}
Build By <b>$KBUILD_BUILD_USER</b>
<b>SHA512SUM</b>: <code>$sha512_hash</code>"
  curl -F document=@$ZIP2 "https://api.telegram.org/bot$token/sendDocument" \
    -F chat_id="$chat_id" \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="
                          LOGGER BUILD FILE
took ${minutes} minute(s) and ${seconds} second(s).
USING DEFCONFIG <b>$DEFCONFIG_NAME</b> "
}



error_handler() {
  cd ~/AnyKernel
  mv ~/log_build.txt .
  ZIP=log_build.txt
  minutes=$(($DIFF / 60))
  seconds=$(($DIFF % 60))
  curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
    -F chat_id="$chat_id" \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="
                          Build encountered an error.
took ${minutes} minute(s) and ${seconds} second(s).
USING DEFCONFIG <b>$DEFCONFIG_NAME</b>
For ${DEVICE_NAME}
Build By <b>$KBUILD_BUILD_USER</b> "
  exit 1
}

compile() {
  cd ~/kernel
  #ubah nama kernel dan dev builder
  printf "\nFinal Repository kernel Should Look Like...\n" && ls -lAog ~/kernel
  export ARCH=arm64

  #mulai mengcompile kernel
  [ -d "out" ] && rm -rf out
  mkdir -p out

  make O=out ARCH=arm64 $DEFCONFIG_NAME

  PATH="${PWD}/clang/bin:${PATH}" \
  make -j$(nproc --all) O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CC="clang" \
    LD=ld.lld \
    NM=llvm-nm \
    AR=llvm-ar \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabihf-" \
    CONFIG_NO_ERROR_ON_MISMATCH=y

  cp out/arch/arm64/boot/Image.gz-dtb ~/AnyKernel
}

zipping() {
  cd ~/AnyKernel
  echo $NAME_KERNEL > name_kernel.txt
  zip -r9 ${NAME_KERNEL}-${VENDOR_NAME}-${TANGGAL}.zip *
  cd ..
}

trap error_handler ERR
{
initial_kernel 2>&1 | tee ~/log_build.txt
cleaning_cache 2>&1 | tee -a ~/log_build.txt
clone_git 2>&1 | tee -a ~/log_build.txt
sendinfo 2>&1 | tee -a ~/log_build.txt
compile 2>&1 | tee -a ~/log_build.txt
zipping 2>&1 | tee -a ~/log_build.txt
END=$(date +"%s")
DIFF=$(($END - $START))
} 
push
