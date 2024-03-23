# toolchains_llvm sysroot package generation

This repo contains the definitions and scripts to build `sysroot` packages for `x86_64` and
`aarch64` (aka `arm64`) for use with the Bazel [toolchains_llvm](https://github.com/bazel-contrib/toolchains_llvm) ruleset.

A matching text article for this repository can be found on my website: [Sysroot package generation for use with toolchains_llvm](https://steven.casagrande.io/articles/sysroot-generation-toolchains-llvm)

The source here is based off of [the sysroot generation code in gcc-toolchain](https://github.com/f0rmiga/gcc-toolchain/tree/main/sysroot),
authored by [@f0rmiga](https://github.com/f0rmiga).

Modifications have been made to:
- generate a valid sysroot package for use with toolchains_llvm instead of [gcc-toolchain](https://github.com/f0rmiga/gcc-toolchain)
- simplified to remove code that I didn't need
- and expanded where necessary to show how to fetch RHEL 8 specific files

### Key Versions 

The stock version of [`Dockerfile`](./Dockerfile) will produce a sysroot with the following library versions.
If you need different versions, I encourage you to go in and make the necessary changes.

Built from source:
- kernel headers 4.18
- glibc 2.28
- libstdc++ 10.3.0

Fetched from RHEL-UBI 8 container:
- openssl
- cyrus-sasl

## Building and using the sysroot packages

Use the [`build.sh`](./build.sh) script to build the `sysroot` package using Docker. The current restriction is
that the container must run in `x86_64`. The sysroot package for other architectures are built using
cross-compilation from `x86_64`. That is, building a sysroot package on an Apple Silicon machine
is not supported at this time.

### Using the build script

The entrypoint is `build.sh` that takes three args:

- The target architecture (`x86_64` or `aarch64`)
- The output directory path for the generated `.tar.xz` file
- The target "variant". One of:
  - `base`, containing just the kernel, glibc, and libstdc++ files
  - `ssl`, containing `base` plus `openssl` and `cyrus-sasl` from a RHEL-UBI 8 container

```shell
./build.sh x86_64 . ssl
./build.sh aarch64 . ssl
```

In the end you'll have a compressed size of ~55MB for x86_64 and ~35MB for aarch64.

### Using the sysroot package with toolchains_llvm

https://github.com/bazel-contrib/toolchains_llvm?tab=readme-ov-file#sysroots

`WORKSPACE` implementation

https://github.com/bazel-contrib/toolchains_llvm/blob/1.0.0/tests/WORKSPACE#L116

`bzlmod` implementation

https://github.com/bazel-contrib/toolchains_llvm/blob/1.0.0/tests/MODULE.bazel#L145
