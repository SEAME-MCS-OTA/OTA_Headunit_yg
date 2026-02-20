DESCRIPTION = "OTA backend service"
LICENSE = "MIT"

inherit systemd externalsrc

EXTERNALSRC ?= "/work/services/ota-backend"
S = "${EXTERNALSRC}"

SRC_URI = ""
EXTERNALSRC_SYMLINKS = ""

SYSTEMD_SERVICE:${PN} = "ota-backend.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += " \
    python3-core \
    python3-logging \
    python3-requests \
    python3-fastapi \
    python3-uvicorn \
    python3-pydantic \
    rauc \
    "

FILES:${PN} += " \
    /usr/bin/ota-backend \
    /usr/lib/ota-backend \
    /usr/lib/systemd/system/ota-backend.service \
    /etc/ota-backend \
    "

do_install:append() {
    install -d ${D}/usr/lib/ota-backend
    cp -r ${S}/app ${D}/usr/lib/ota-backend/
    install -d ${D}/usr/bin
    install -m 0755 ${THISDIR}/files/ota-backend ${D}/usr/bin/ota-backend
    install -m 0644 ${S}/config/default-config.json ${D}/etc/ota-backend/config.json
    install -d ${D}/usr/lib/systemd/system
    install -m 0644 ${S}/systemd/ota-backend.service ${D}/usr/lib/systemd/system/ota-backend.service
}
