import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root
    anchors.fill: parent
    color: "transparent"

    Id5Theme { id: theme }

    property var otaState: ({})
    signal goToOta()
    signal goToNav()
    signal goToMedia()

    function vehicleName() {
        return "Volkswagen ID.5"
    }

    function currentVersion() {
        var ota = root.otaState.ota || {}
        var cur = ota.current_version || root.otaState.currentVersion || "-"
        cur = String(cur).trim()
        return (cur.length > 0 && cur !== "unknown") ? cur : "-"
    }

    function currentPhase() {
        var ota = root.otaState.ota || {}
        var ph = String(ota.phase || "-").trim()
        return ph.length > 0 ? ph : "-"
    }

    function currentEvent() {
        var ota = root.otaState.ota || {}
        var ev = String(ota.event || "-").trim()
        return ev.length > 0 ? ev : "-"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.bgTop }
            GradientStop { position: 1.0; color: theme.bgBottom }
        }
    }

    Rectangle {
        width: 340
        height: 340
        radius: 170
        x: parent.width - width * 0.7
        y: -height * 0.45
        color: Qt.rgba(0.29, 0.64, 1.0, 0.18)
    }

    Rectangle {
        width: 260
        height: 260
        radius: 130
        x: -width * 0.35
        y: parent.height - height * 0.6
        color: Qt.rgba(0.45, 0.78, 1.0, 0.12)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 16

        Text {
            text: "ID.5 Digital Cockpit"
            color: theme.textPrimary
            font.pixelSize: 38
            font.bold: true
            font.family: theme.fontFamily
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "Connected OTA Head Unit"
            color: theme.textSecondary
            font.pixelSize: 15
            font.family: theme.fontFamily
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            SimpleButton { label: "Home"; active: true }
            SimpleButton { label: "OTA Status"; variant: "accent"; onClicked: root.goToOta() }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 128
            radius: theme.radiusLg
            color: theme.card
            border.width: 1
            border.color: theme.stroke

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: 220
                height: 120
                radius: theme.radiusLg
                color: theme.card
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                RowLayout {
                    spacing: 22
                    Text {
                        text: "Vehicle: " + root.vehicleName()
                        color: theme.textPrimary
                        font.pixelSize: 20
                        font.family: theme.fontFamily
                    }
                    Text {
                        text: "Version: " + root.currentVersion()
                        color: theme.textPrimary
                        font.pixelSize: 20
                        font.family: theme.fontFamily
                    }
                }

                RowLayout {
                    spacing: 24
                    Rectangle {
                        radius: theme.radiusSm
                        height: 42
                        Layout.minimumWidth: 230
                        Layout.preferredWidth: Math.max(230, phaseLabel.implicitWidth + 44)
                        color: "#1E426A"
                        border.width: 1
                        border.color: theme.accentSoft
                        Text {
                            id: phaseLabel
                            anchors.centerIn: parent
                            text: "Phase: " + root.currentPhase()
                            color: theme.accentSoft
                            font.pixelSize: 13
                            font.family: theme.fontFamily
                        }
                    }
                    Rectangle {
                        radius: theme.radiusSm
                        height: 42
                        Layout.minimumWidth: 210
                        Layout.preferredWidth: Math.max(210, eventLabel.implicitWidth + 44)
                        color: "#173D35"
                        border.width: 1
                        border.color: theme.ok
                        Text {
                            id: eventLabel
                            anchors.centerIn: parent
                            text: "Event: " + root.currentEvent()
                            color: theme.ok
                            font.pixelSize: 13
                            font.family: theme.fontFamily
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 14
            columnSpacing: 14

            Rectangle {
                color: theme.cardAlt
                radius: theme.radiusLg
                border.width: 1
                border.color: theme.stroke
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: "Media"
                    color: theme.textPrimary
                    font.pixelSize: 28
                    font.family: theme.fontFamily
                }
                MouseArea { anchors.fill: parent; onClicked: root.goToMedia() }
            }

            Rectangle {
                color: theme.cardAlt
                radius: theme.radiusLg
                border.width: 1
                border.color: theme.stroke
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: "Navigation"
                    color: theme.textPrimary
                    font.pixelSize: 28
                    font.family: theme.fontFamily
                }
                MouseArea { anchors.fill: parent; onClicked: root.goToNav() }
            }

            Rectangle {
                color: theme.cardSoft
                radius: theme.radiusLg
                border.width: 1
                border.color: theme.stroke
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: "Phone"
                    color: theme.textSecondary
                    font.pixelSize: 24
                    font.family: theme.fontFamily
                }
            }

            Rectangle {
                color: theme.cardSoft
                radius: theme.radiusLg
                border.width: 1
                border.color: theme.stroke
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: "Settings"
                    color: theme.textSecondary
                    font.pixelSize: 24
                    font.family: theme.fontFamily
                }
            }
        }
    }
}
