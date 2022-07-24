
#require rust-cross-canadian-common.inc

#RUST_ALTERNATE_EXE_PATH = "${STAGING_LIBDIR_NATIVE}/llvm-rust/bin/llvm-config"

require rust.inc

#DEPENDS += "nativesdk-rust-llvm (=${PV})"


#DEPENDS += "  \
#            virtual/${HOST_PREFIX}gcc-crosssdk \
#            virtual/nativesdk-libc rust-native \
#            virtual/${TARGET_PREFIX}compilerlibs \
#            virtual/nativesdk-${HOST_PREFIX}compilerlibs \
#            gcc-cross-${TARGET_ARCH} \
#           "

# The host tools are likely not to be able to do the necessary operation on
# the target architecturea. Alternatively one could check compatibility
# between host/target.
EXCLUDE_FROM_SHLIBS_${RUSTLIB_TARGET_PN} = "1"

DEBUG_PREFIX_MAP = "-fdebug-prefix-map=${WORKDIR}=/usr/src/debug/${PN}/${EXTENDPE}${PV}-${PR} \
                    -fdebug-prefix-map=${STAGING_DIR_HOST}= \
                    -fdebug-prefix-map=${STAGING_DIR_NATIVE}= \
                    "

RUST_TARGETGENS = "BUILD HOST TARGET"

INHIBIT_DEFAULT_RUST_DEPS = "1"

DEPENDS += "rust-native"

export WRAPPER_TARGET_CC = "${CCACHE}${TARGET_PREFIX}gcc --sysroot=${STAGING_DIR_TARGET} ${TARGET_CC_ARCH} ${SECURITY_NOPIE_CFLAGS}"
export WRAPPER_TARGET_CXX = "${CCACHE}${TARGET_PREFIX}g++ --sysroot=${STAGING_DIR_TARGET} ${TARGET_CC_ARCH} ${SECURITY_NOPIE_CFLAGS}"
export WRAPPER_TARGET_CCLD = "${TARGET_PREFIX}gcc --sysroot=${STAGING_DIR_TARGET} ${TARGET_CC_ARCH} ${SECURITY_NOPIE_CFLAGS}"
export WRAPPER_TARGET_LDFLAGS = "${TARGET_LDFLAGS}"
export WRAPPER_TARGET_AR = "${TARGET_PREFIX}ar"

#python do_configure:prepend() {
#    targets = [d.getVar("TARGET_SYS", True), "{}-unknown-linux-gnu".format(d.getVar("HOST_ARCH", True))]
#    hosts = ["{}-unknown-linux-gnu".format(d.getVar("HOST_ARCH", True))]
#}

INSANE_SKIP:${RUSTLIB_TARGET_PN} = "file-rdeps arch ldflags"
SKIP_FILEDEPS:${RUSTLIB_TARGET_PN} = "1"

INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_SYSROOT_STRIP = "1"


RUST_TOOLS_CLIPPY_PN = "rust-tools-clippy"
RUST_TOOLS_RUSTFMT_PN = "rust-tools-rustfmt"
RUST_TOOLS_PKGS = "${RUST_TOOLS_CLIPPY_PN} ${RUST_TOOLS_RUSTFMT_PN}"

PACKAGES = "${RUST_TOOLS_CLIPPY_PN} ${RUST_TOOLS_RUSTFMT_PN} ${PN}"
RDEPENDS:${PN} += "${RUST_TOOLS_PKGS}"

do_compile () {
    rust_runx build --stage 2 src/tools/clippy
    rust_runx build --stage 2 src/tools/rustfmt
}

do_install () {
    #SYS_BINDIR=$(dirname ${D}${bindir})

    install -d ${D}${PKG_SYS_BINDIR}
    cp build/${RUST_BUILD_SYS}/stage2-tools-bin/* ${D}${PKG_SYS_BINDIR}
    for i in ${D}${PKG_SYS_BINDIR}/*; do
	chrpath -r "\$ORIGIN/../lib" ${i}
    done

    chown -R root.root ${D}
}

ALLOW_EMPTY:${PN} = "1"

PKG_SYS_BINDIR = "${SDKPATHNATIVE}/usr/bin"
FILES:${RUST_TOOLS_CLIPPY_PN} = "${PKG_SYS_BINDIR}/cargo-clippy ${PKG_SYS_BINDIR}/clippy-driver"
FILES:${RUST_TOOLS_RUSTFMT_PN} = "${PKG_SYS_BINDIR}/rustfmt"

SUMMARY:${PN} = "Rust helper tools"
SUMMARY:${RUST_TOOLS_CLIPPY_PN} = "A collection of lints to catch common mistakes and improve your Rust code"
SUMMARY:${RUST_TOOLS_RUSTFMT_PN} = "A tool for formatting Rust code according to style guidelines"

BBCLASSEXTEND = "nativesdk"
