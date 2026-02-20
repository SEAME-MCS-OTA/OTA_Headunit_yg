FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://wpa_supplicant.conf"

FILES:${PN} += "/etc/wpa_supplicant/wpa_supplicant.conf"
FILES:${PN} += "/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"

PACKAGE_WRITE_DEPS += ""

do_install:append() {
    install -d ${D}/etc/wpa_supplicant
    install -m 0600 ${WORKDIR}/wpa_supplicant.conf ${D}/etc/wpa_supplicant/wpa_supplicant.conf
    install -m 0600 ${WORKDIR}/wpa_supplicant.conf ${D}/etc/wpa_supplicant/wpa_supplicant-wlan0.conf
}
