#!/bin/bash -e
VER=${1-4.2.0}
BUILD_TYPE=${2-Release}

URL=https://download.zeek.org/zeek-${VER}.tar.gz

echo VER is $VER
echo URL is $URL
echo BUILD_TYPE is $BUILD_TYPE

cd /usr/src/
if [ ! -e ${BRO}-${VER}.tar.gz ] ; then
    wget -c $URL
fi
if [ ! -d zeek-${VER} ]; then
    tar xvzf zeek-${VER}.tar.gz
fi
cd zeek-${VER}
./configure --prefix=/usr/local/zeek --build-type="${BUILD_TYPE}"
make -j $(nproc) install