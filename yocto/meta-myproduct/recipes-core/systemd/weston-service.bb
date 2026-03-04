DESCRIPTION = "Custom weston systemd service"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch systemd

SYSTEMD_SERVICE:${PN} = "seatd.service weston.service http-time-sync.service persist-machine-id.service myproduct-timezone.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

SRC_URI = "file://seatd.service \
           file://weston.service \
           file://http-time-sync.service \
           file://http-time-sync.sh \
           file://persist-machine-id.service \
           file://persist-machine-id.sh \
           file://myproduct-timezone.service \
           file://myproduct-timezone.sh \
           file://10-myproduct-timesyncd.conf"

S = "${WORKDIR}"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/seatd.service ${D}${systemd_system_unitdir}/seatd.service
    install -m 0644 ${WORKDIR}/weston.service ${D}${systemd_system_unitdir}/weston.service
    install -m 0644 ${WORKDIR}/http-time-sync.service ${D}${systemd_system_unitdir}/http-time-sync.service
    install -m 0644 ${WORKDIR}/persist-machine-id.service ${D}${systemd_system_unitdir}/persist-machine-id.service
    install -m 0644 ${WORKDIR}/myproduct-timezone.service ${D}${systemd_system_unitdir}/myproduct-timezone.service
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/http-time-sync.sh ${D}${sbindir}/http-time-sync.sh
    install -m 0755 ${WORKDIR}/persist-machine-id.sh ${D}${sbindir}/persist-machine-id.sh
    install -m 0755 ${WORKDIR}/myproduct-timezone.sh ${D}${sbindir}/myproduct-timezone.sh
    install -d ${D}${sysconfdir}/systemd/timesyncd.conf.d
    install -m 0644 ${WORKDIR}/10-myproduct-timesyncd.conf ${D}${sysconfdir}/systemd/timesyncd.conf.d/10-myproduct.conf
}

FILES:${PN} += " \
    ${systemd_system_unitdir}/seatd.service \
    ${systemd_system_unitdir}/weston.service \
    ${systemd_system_unitdir}/http-time-sync.service \
    ${systemd_system_unitdir}/persist-machine-id.service \
    ${systemd_system_unitdir}/myproduct-timezone.service \
    ${sbindir}/http-time-sync.sh \
    ${sbindir}/persist-machine-id.sh \
    ${sbindir}/myproduct-timezone.sh \
    ${sysconfdir}/systemd/timesyncd.conf.d/10-myproduct.conf \
    "
