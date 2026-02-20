DESCRIPTION = "RAUC system.conf and certificate"
LICENSE = "MIT"

SRC_URI = "file://system.conf file://ca.cert.pem"

S = "${WORKDIR}"

do_install() {
    install -d ${D}/etc/rauc
    install -m 0644 ${WORKDIR}/system.conf ${D}/etc/rauc/system.conf
    install -m 0644 ${WORKDIR}/ca.cert.pem ${D}/etc/rauc/ca.cert.pem
}
