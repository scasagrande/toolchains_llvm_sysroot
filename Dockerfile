# Copyright (c) Joby Aviation 2022
# Original authors: Thulio Ferraz Assis (thulio@aspect.dev), Aspect.dev
#
# Copyright (c) Thulio Ferraz Assis 2024
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# This file as been modified by @scasagrande to support the generation
# of sysroot packages valid for use with the toolchains_llvm bazel rule, and
# to support the insertion of RHEL specific libraries.
#
# Original: https://github.com/f0rmiga/gcc-toolchain/blob/main/sysroot/build.sh
# toolchains_llvm: https://github.com/bazel-contrib/toolchains_llvm
#

FROM ubuntu:22.04 AS base_image

WORKDIR /bin
SHELL ["/bin/bash", "-c"]

WORKDIR /
RUN apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y \
        bison \
        bzip2 \
        curl \
        file \
        gawk \
        gettext \
        less \
        libz-dev \
        m4 \
        make \
        pkg-config \
        python3 \
        rsync \
        texinfo \
        xsltproc \
        xz-utils

####################################################################################################
# Download steps
####################################################################################################

FROM base_image AS kernel_download
WORKDIR /downloads/kernel
RUN curl --fail-early --location https://github.com/torvalds/linux/archive/refs/tags/v4.18.tar.gz \
        | tar --gzip --extract --strip-components=1 --file -

FROM base_image AS glibc_download
WORKDIR /downloads/glibc
RUN curl --fail-early --location https://ftp.gnu.org/gnu/glibc/glibc-2.28.tar.xz \
        | tar --xz --extract --strip-components=1 --file -

FROM base_image AS gcc_download
WORKDIR /downloads/gcc
RUN curl --fail-early --location https://ftp.gnu.org/gnu/gcc/gcc-10.3.0/gcc-10.3.0.tar.xz \
        | tar --xz --extract --strip-components=1 --file -
RUN ./contrib/download_prerequisites

FROM base_image AS build_image

WORKDIR /opt/gcc/aarch64
RUN curl --fail-early --location https://toolchains.bootlin.com/downloads/releases/toolchains/aarch64/tarballs/aarch64--glibc--stable-2022.08-1.tar.bz2 \
        | tar --bzip --extract --strip-components=1 --file -
WORKDIR /opt/gcc/aarch64/bin
RUN --mount=source=create_symlinks.sh,target=/usr/bin/create_symlinks.sh create_symlinks.sh arm-linux- arm-linux-gnueabihf-

WORKDIR /opt/gcc/x86_64
RUN curl --fail-early --location https://toolchains.bootlin.com/downloads/releases/toolchains/x86-64-core-i7/tarballs/x86-64-core-i7--glibc--stable-2022.08-1.tar.bz2 \
        | tar --bzip --extract --strip-components=1 --file -
WORKDIR /opt/gcc/x86_64/bin
RUN --mount=source=create_symlinks.sh,target=/usr/bin/create_symlinks.sh create_symlinks.sh x86_64-linux-
WORKDIR /

####################################################################################################
# Setup steps
####################################################################################################

ARG ARCH
ENV ARCH="${ARCH}"
RUN if [ -z "${ARCH}" ]; then >&2 echo "Missing ARCH argument"; exit 1; fi
RUN ln -s "/opt/gcc/${ARCH}/bin/${ARCH}-linux-cpp.br_real" /lib/cpp

ENV PATH="/opt/gcc/x86_64/bin:/opt/gcc/${ARCH}/bin:${PATH}"

####################################################################################################
# Build steps
####################################################################################################

FROM build_image AS kernel
COPY --from=kernel_download /downloads/kernel /build/kernel
WORKDIR /build/kernel
RUN --mount=source=build_kernel.sh,target=/usr/bin/build_kernel.sh build_kernel.sh

FROM build_image AS glibc
COPY --from=kernel /var/buildlibs/kernel /var/buildlibs/kernel
COPY --from=glibc_download /downloads/glibc /build/glibc
WORKDIR /build/glibc/build
RUN --mount=source=configure.sh,target=/usr/bin/configure.sh configure.sh \
        --enable-kernel=4.18 \
        --disable-werror \
        --prefix=/usr \
        --with-headers=/var/buildlibs/kernel/usr/include \
        --with-tls \
        libc_cv_slibdir=/usr/lib \
        || (cat config.log && exit 1)
RUN make all --jobs $(nproc)
RUN make DESTDIR=/var/buildlibs/glibc install

FROM glibc AS glibc_pruned
WORKDIR /var/buildlibs/glibc
RUN rm -rf etc/ sbin/ var/ usr/bin/ usr/libexec/ usr/sbin/ usr/share/

FROM build_image AS gcc
COPY --from=gcc_download /downloads/gcc /build/gcc
WORKDIR /build/gcc/build
COPY --from=kernel /var/buildlibs/kernel /var/builds/sysroot
COPY --from=glibc /var/buildlibs/glibc /var/builds/sysroot
RUN --mount=source=configure.sh,target=/usr/bin/configure.sh IS_GCC_BUILD=1 configure.sh \
        --enable-default-pie \
        --enable-languages=c,c++,fortran \
        --disable-multilib \
        --prefix=/var/buildlibs/gcc \
        --enable-libstdcxx-threads \
        --with-build-sysroot=/var/builds/sysroot \
        --with-sysroot=/var/builds/sysroot \
        || (cat config.log && exit 1)
RUN make --jobs $(nproc) all-gcc
RUN make install-gcc
RUN rm -v "/opt/gcc/${ARCH}/bin/"*{gcc,g++,cpp}
ENV PATH="/var/buildlibs/gcc/bin:${PATH}"
RUN make --jobs $(nproc)
RUN make uninstall
RUN make install all-target-libgcc
RUN make install all-target-libgfortran
RUN make install all-target-libstdc++-v3

FROM gcc as gcc_pruned
RUN --mount=source=prune_gcc.sh,target=/usr/bin/prune_gcc.sh prune_gcc.sh

####################################################################################################
# Extra libs
####################################################################################################

###################
# RHEL ssl packages
###################

FROM --platform=linux/arm64 registry.access.redhat.com/ubi8 as rhel_image_base

RUN dnf -y install openssl-devel cyrus-sasl-devel
WORKDIR /var/builds/sysroot
RUN mkdir -p usr/include
RUN cp -R /usr/include/openssl usr/include
RUN cp -R /usr/include/sasl usr/include
RUN mkdir -p usr/lib64
RUN cp -R /usr/lib64/.*ssl* usr/lib64
RUN cp -R /usr/lib64/*ssl* usr/lib64
RUN cp -R /usr/lib64/*sasl*.so* usr/lib64
RUN cp -R /usr/lib64/sasl2 usr/lib64
RUN cp -R /usr/lib64/*crypt* usr/lib64

####################################################################################################
# Assemble final sysroots
####################################################################################################

FROM build_image AS sysroot_base
COPY --from=kernel /var/buildlibs/kernel /var/builds/sysroot
COPY --from=glibc_pruned /var/buildlibs/glibc /var/builds/sysroot
COPY --from=gcc_pruned /var/buildlibs/gcc /var/builds/sysroot/usr

FROM build_image as sysroot_ssl
COPY --from=sysroot_base /var/builds/sysroot /var/builds/sysroot
COPY --from=rhel_image_base /var/builds/sysroot /var/builds/sysroot
