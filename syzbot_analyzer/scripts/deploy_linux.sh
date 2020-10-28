#!/bin/bash
# Xiaochen Zou 2020, University of California-Riverside
#
# Usage ./deploy_linux fixed linux_path patch_path [linux_commit, config_url]

set -ex

echo "running deploy_linux.sh"

function clean_and_jump() {
  git stash --all
  git checkout -f $COMMIT
}

function copy_log_then_exit() {
  LOG=$1
  cp $LOG $CASE_PATH/$LOG-deploy_linux
  exit 1
}

if [ $# -lt 4 ] || [ $# -eq 5 ] || [ $# -gt 6 ]; then
  echo "Usage ./deploy_linux gcc_version fixed linux_path package_path [linux_commit, config_url]"
  exit 1
fi

COMPILER_VERSION=$1
FIXED=$2
LINUX=$3
PATCH=$4/patches/kasan.patch
echo "Compiler: "$COMPILER_VERSION | grep gcc && \
COMPILER=$4/tools/$COMPILER_VERSION/bin/gcc || COMPILER=$4/tools/$COMPILER_VERSION/bin/clang

if [ $# -eq 6 ]; then
  COMMIT=$5
  CONFIG=$6
fi

cd $LINUX
cd ..
CASE_PATH=`pwd`
cd linux
if [ $# -eq 4 ]; then
  #patch -p1 -N -R < $PATCH
  echo "no more patch"
fi
if [ $# -eq 6 ]; then
  if [ "$FIXED" != "1" ]; then
    git stash
    git clean -d -f -e THIS_KERNEL_IS_BEING_USED
    CURRENT_HEAD=`git rev-parse HEAD`
    if [ "$CURRENT_HEAD" != "$COMMIT" ]; then
      #make clean CC=$COMPILER
      #git stash --all
      git checkout -f $COMMIT || (git pull https://github.com/torvalds/linux.git master > /dev/null 2>&1 && git checkout -f $COMMIT)
    fi
    curl $CONFIG > .config
  else
    git format-patch -1 $COMMIT --stdout > fixed.patch
    patch -p1 -N -i fixed.patch || exit 1
    curl $CONFIG > .config
  fi
fi

# Panic on data corruption may stop the fuzzing session
sed -i "s/CONFIG_BUG_ON_DATA_CORRUPTION=y/# CONFIG_BUG_ON_DATA_CORRUPTION is not set/g" .config
make olddefconfig CC=$COMPILER
make -j16 CC=$COMPILER > make.log 2>&1 || copy_log_then_exit make.log
exit 0