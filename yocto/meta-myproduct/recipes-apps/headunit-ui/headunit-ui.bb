DESCRIPTION = "Qt Head Unit UI"
LICENSE = "MIT"

inherit qt6-cmake systemd externalsrc

EXTERNALSRC ?= "/work/ui/qt-headunit"
S = "${EXTERNALSRC}"

SRC_URI = ""
EXTERNALSRC_SYMLINKS = ""

SYSTEMD_SERVICE:${PN} = "headunit.service ui-log-collector.service ui-log-collector.timer"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += " \
    qtbase \
    qtdeclarative \
    qtdeclarative-qmlplugins \
    qtwebengine \
    qtwebengine-qmlplugins \
    qtwayland \
    "

DEPENDS += "qtdeclarative qtdeclarative-native qtwebengine"

do_install:append() {
    install -d ${D}/usr/lib/systemd/system
    install -m 0644 ${S}/systemd/headunit.service ${D}/usr/lib/systemd/system/headunit.service
    install -m 0644 ${S}/systemd/ui-log-collector.service ${D}/usr/lib/systemd/system/ui-log-collector.service
    install -m 0644 ${S}/systemd/ui-log-collector.timer ${D}/usr/lib/systemd/system/ui-log-collector.timer
    install -d ${D}/usr/lib/headunit-ui
    install -m 0755 ${S}/scripts/collect-ui-logs.sh ${D}/usr/lib/headunit-ui/collect-ui-logs.sh
    install -d ${D}/etc/xdg/weston
    install -m 0644 ${S}/weston/weston.ini ${D}/etc/xdg/weston/weston.ini
}

FILES:${PN} += " \
    /usr/bin/headunit-ui \
    /usr/lib/systemd/system/headunit.service \
    /usr/lib/systemd/system/ui-log-collector.service \
    /usr/lib/systemd/system/ui-log-collector.timer \
    /usr/lib/headunit-ui/collect-ui-logs.sh \
    /etc/xdg/weston/weston.ini \
    "
