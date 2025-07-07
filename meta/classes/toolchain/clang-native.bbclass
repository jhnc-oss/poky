BUILD_CC = "${CCACHE}${BUILD_PREFIX}clang ${BUILD_CC_ARCH}"
BUILD_CXX = "${CCACHE}${BUILD_PREFIX}clang++ ${BUILD_CC_ARCH}"
BUILD_FC = "${BUILD_PREFIX}gfortran ${BUILD_CC_ARCH}"
BUILD_CPP = "${BUILD_PREFIX}clang ${BUILD_CC_ARCH} -E"
BUILD_LD = "${BUILD_PREFIX}ld ${BUILD_LD_ARCH}"
BUILD_CCLD = "${BUILD_PREFIX}clang ${BUILD_CC_ARCH}"
BUILD_AR = "${BUILD_PREFIX}llvm-ar"
BUILD_AS = "${BUILD_PREFIX}as ${BUILD_AS_ARCH}"
BUILD_RANLIB = "${BUILD_PREFIX}llvm-ranlib -D"
BUILD_STRIP = "${BUILD_PREFIX}llvm-strip"
BUILD_OBJCOPY = "${BUILD_PREFIX}llvm-objcopy"
BUILD_OBJDUMP = "${BUILD_PREFIX}llvm-objdump"
BUILD_NM = "${BUILD_PREFIX}llvm-nm"
BUILD_READELF = "${BUILD_PREFIX}llvm-readelf"

DEPENDS += "clang-native libcxx-native compiler-rt-native"

LDFLAGS += " --rtlib=libgcc --unwindlib=libgcc"

# Some systems can have mixed gcc development headers, such as pieces of both gcc 13
# and 14 which can cause build failures, particularly if libgcc and libstdc++ for
# gcc 13 are present but only libgcc for gcc 14 and not libstdc++ when the gcc
# version is gcc 13. Force the gcc install that matches gcc itself
BUILD_CFLAGS:append:class-native = " --gcc-install-dir=$(dirname $(gcc -print-libgcc-file-name))"
BUILD_CXXFLAGS:append:class-native = " --gcc-install-dir=$(dirname $(gcc -print-libgcc-file-name))"
