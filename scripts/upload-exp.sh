#!/bin/bash
# Xiaochen Zou 2020, University of California-Riverside
#
# Usage ./upload-exp.sh case_path syz_repro_url ssh_port image_path syz_commit type c_repro i386
# EXITCODE: 2: syz-execprog supports -enable. 3: syz-execprog do not supports -enable.

set -ex

if [ $# -ne 8 ]; then
  echo "Usage ./upload-exp.sh case_path syz_repro_url ssh_port image_path syz_commit type, c_repro i386"
  exit 1
fi

CASE_PATH=$1
TESTCASE=$2
PORT=$3
IMAGE_PATH=$4
SYZKALLER=$5
TYPE=$6
C_REPRO=$7
I386=$8
EXITCODE=3

M32=""
ARCH="amd64"
if [ "$I386" != "None" ]; then
    M32="-m32"
    ARCH="386"
fi

cd $CASE_PATH
if [ ! -d "$CASE_PATH/poc" ]; then
    mkdir $CASE_PATH/poc
fi

cd $CASE_PATH/poc
if [ "$TYPE" == "1" ]; then
    cp $TESTCASE ./testcase
else
    curl $TESTCASE > testcase
fi
scp -F /dev/null -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
    -i $IMAGE_PATH/stretch.img.key -P $PORT ./testcase root@localhost:/root

if [ "$C_REPRO" != "None" ]; then
    curl $C_REPRO > poc.c
    gcc -pthread $M32 -static -o poc poc.c || echo "Error occur when compiling poc"

    scp -F /dev/null -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
    -i $IMAGE_PATH/stretch.img.key -P $PORT ./poc root@localhost:/root
fi

if [ ! -d "$CASE_PATH/poc/gopath" ]; then
    mkdir $CASE_PATH/poc/gopath
fi
export GOPATH=$CASE_PATH/poc/gopath
if [ ! -d "$GOPATH/src/github.com/google/syzkaller" ]; then
    go get -u -d github.com/google/syzkaller/prog
fi
cd $GOPATH/src/github.com/google/syzkaller || exit 1
make clean
git stash --all
git checkout $SYZKALLER
git rev-list HEAD | grep $(git rev-parse dfd609eca1871f01757d6b04b19fc273c87c14e5) || EXITCODE=2
make TARGETARCH=$ARCH TARGETVMARCH=amd64 execprog executor
scp -F /dev/null -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
    -i $IMAGE_PATH/stretch.img.key -P $PORT bin/linux_amd64/syz-execprog bin/linux_amd64/syz-executor root@localhost:/root

exit $EXITCODE