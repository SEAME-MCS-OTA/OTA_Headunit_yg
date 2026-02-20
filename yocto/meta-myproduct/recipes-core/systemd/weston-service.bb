DESCRIPTION = "Custom weston systemd service"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch systemd

SYSTEMD_SERVICE:${PN} = "seatd.service weston.service http-time-sync.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

SRC_URI = "file://seatd.service file://weston.service file://http-time-sync.service file://http-time-sync.sh file://10-myproduct-timesyncd.conf"

S = "${WORKDIR}"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/seatd.service ${D}${systemd_system_unitdir}/seatd.service
    install -m 0644 ${WORKDIR}/weston.service ${D}${systemd_system_unitdir}/weston.service
    install -m 0644 ${WORKDIR}/http-time-sync.service ${D}${systemd_system_unitdir}/http-time-sync.service
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/http-time-sync.sh ${D}${sbindir}/http-time-sync.sh
    install -d ${D}${sysconfdir}/systemd/timesyncd.conf.d
    install -m 0644 ${WORKDIR}/10-myproduct-timesyncd.conf ${D}${sysconfdir}/systemd/timesyncd.conf.d/10-myproduct.conf
}

FILES:${PN} += " \
    ${systemd_system_unitdir}/seatd.service \
    ${systemd_system_unitdir}/weston.service \
    ${systemd_system_unitdir}/http-time-sync.service \
    ${sbindir}/http-time-sync.sh \
    ${sysconfdir}/systemd/timesyncd.conf.d/10-myproduct.conf \
    "
