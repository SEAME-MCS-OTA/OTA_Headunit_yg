DESCRIPTION = "IVI Head Unit image"
LICENSE = "MIT"

inherit core-image

ROOTFS_POSTPROCESS_COMMAND += "enable_wlan0_wpa; disable_getty_tty1;"

enable_wlan0_wpa() {
    if [ -e ${IMAGE_ROOTFS}/usr/lib/systemd/system/wpa_supplicant@.service ]; then
        install -d ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants
        ln -sf /usr/lib/systemd/system/wpa_supplicant@.service \
            ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service
    fi
}

disable_getty_tty1() {
    # Disable and mask getty on tty1 so weston can own tty1 consistently.
    rm -f ${IMAGE_ROOTFS}/etc/systemd/system/getty.target.wants/getty@tty1.service
    rm -f ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants/getty@tty1.service
    install -d ${IMAGE_ROOTFS}/etc/systemd/system
    ln -sf /dev/null ${IMAGE_ROOTFS}/etc/systemd/system/getty@tty1.service
}

BAD_RECOMMENDATIONS += "weston-init"

IMAGE_INSTALL:append = " \
    weston \
    weston-service \
    seatd \
    rauc \
    openssh \
    headunit-ui \
    myproduct-systemd-preset \
    wpa-supplicant \
    dhcpcd \
    linux-firmware-rpidistro-bcm43455 \
    bluez-firmware-rpidistro-bcm4345c0-hcd \
    kernel-module-brcmfmac \
    openssl \
    qtbase-plugins \
    qtwebengine \
    ca-certificates \
    curl \
    iproute2 \
    iw \
    tzdata \
    "

IMAGE_FEATURES += "splash"

EXTRA_IMAGE_FEATURES += "debug-tweaks"

IMAGE_FSTYPES:append = " wic.gz"
WKS_FILE = "my-hu-image.wks"
