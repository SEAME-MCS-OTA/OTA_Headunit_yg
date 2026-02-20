FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://fstab"

FILES:${PN} += "/etc/fstab"

do_install:append() {
    install -m 0644 ${WORKDIR}/fstab ${D}/etc/fstab

    # Keep timezone hint without owning /etc/localtime here.
    # /etc/localtime is provided by tzdata-core and may otherwise clash in rootfs.
    echo "Europe/Berlin" > ${D}${sysconfdir}/timezone
}
