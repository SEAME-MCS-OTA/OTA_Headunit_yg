DESCRIPTION = "Systemd preset for myproduct"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://99-myproduct.preset"

S = "${WORKDIR}"

do_install() {
    install -d ${D}/etc/systemd/system-preset
    install -m 0644 ${WORKDIR}/99-myproduct.preset ${D}/etc/systemd/system-preset/99-myproduct.preset
}
