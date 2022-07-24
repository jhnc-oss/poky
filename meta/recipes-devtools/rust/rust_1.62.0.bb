require rust-target.inc
require rust-source.inc
require rust-snapshot.inc

INSANE_SKIP:${PN}:class-native = "already-stripped"
FILES:${PN} += "${libdir}/rustlib"
FILES:${PN} += "${libdir}/*.so"
FILES:${PN}-dev = ""

do_compile () {
    rust_runx build --stage 2
}

rust_do_install() {
    rust_runx install
}

rust_do_install:class-nativesdk() {
    PSEUDO_UNLOAD=1 rust_runx install
    chown root.root ${D}/ -R
    rm ${D}${libdir}/rustlib/uninstall.sh
}

rust_do_install:class-target() {
    PSEUDO_UNLOAD=1 rust_runx install
    chown root.root ${D}/ -R
    rm ${D}${libdir}/rustlib/uninstall.sh
}

RUSTLIB_DEP:class-nativesdk = ""