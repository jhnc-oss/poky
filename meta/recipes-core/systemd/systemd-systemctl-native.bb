SUMMARY = "Systemctl executable from systemd"

require systemd.inc

DEPENDS = "gperf-native libcap-native util-linux-native python3-jinja2-native"

inherit pkgconfig meson native

SRC_URI:append = " \
    file://0001-meson-add-install-tag-for-systemctl.patch \
    file://0002-meson-Bypass-certain-config-checks.patch \
"

MESON_TARGET = "systemctl:executable"
MESON_INSTALL_TAGS = "systemctl"
EXTRA_OEMESON:append = " -Dlink-systemctl-shared=false"
