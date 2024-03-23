#!/usr/bin/env bash

set -eux

rm -rf /var/buildlibs/gcc/bin
rm -rf /var/buildlibs/gcc/usr/bin
rm -rf /var/buildlibs/gcc/libexec
rm -rf /var/buildlibs/gcc/share

if [ "$ARCH" == 'x86_64' ]; then
  mv /var/buildlibs/gcc/lib/gcc/${ARCH}-linux /var/buildlibs/gcc/lib/gcc/${ARCH}-linux-gnu
  mv /var/buildlibs/gcc/lib/gcc/${ARCH}-linux-gnu/10.3.0 /var/buildlibs/gcc/lib/gcc/${ARCH}-linux-gnu/10
  mv /var/buildlibs/gcc/include/c++/10.3.0 /var/buildlibs/gcc/include/c++/10
  mv /var/buildlibs/gcc/include/c++/10/${ARCH}-linux /var/buildlibs/gcc/include/c++/10/${ARCH}-linux-gnu
elif [ "$ARCH" == 'aarch64' ]; then
  mv /var/buildlibs/gcc/lib/gcc/${ARCH}-linux /var/buildlibs/gcc/lib/gcc/${ARCH}-linux-gnu
  mv /var/buildlibs/gcc/lib/gcc/${ARCH}-linux-gnu/10.3.0 /var/buildlibs/gcc/lib/gcc/${ARCH}-linux-gnu/10
  mv /var/buildlibs/gcc/${ARCH}-linux/include/c++/10.3.0 /var/buildlibs/gcc/${ARCH}-linux/include/c++/10
  mv /var/buildlibs/gcc/${ARCH}-linux/include/c++/10/${ARCH}-linux /var/buildlibs/gcc/${ARCH}-linux/include/c++/10/${ARCH}-linux-gnu
  mv /var/buildlibs/gcc/${ARCH}-linux/include/c++ /var/buildlibs/gcc/include/c++
  mv /var/buildlibs/gcc/${ARCH}-linux/lib64/* /var/buildlibs/gcc/lib64/
  rm -r /var/buildlibs/gcc/${ARCH}-linux
else
  exit 1
fi
