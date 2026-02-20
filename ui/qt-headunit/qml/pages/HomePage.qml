import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root
    color: "#0E1116"
    anchors.fill: parent

    property var otaState: ({})
    signal goToOta()
    signal goToNav()
    signal goToMedia()

    function vehicleName() {
        var lv = root.otaState.logVehicle || root.otaState.log_vehicle || {}
        var brand = lv.brand || ""
        var series = lv.series || ""
        var name = (brand + " " + series).trim()
        return name.length > 0 ? name : "-"
    }

    function currentVersion() {
        var ota = root.otaState.ota || {}
        return ota.current_version || root.otaState.currentVersion || "1.2.3"
    }

    function phaseText() {
        var ota = root.otaState.ota || {}
        return ota.phase || root.otaState.phase || "-"
    }

    function eventText() {
        var ota = root.otaState.ota || {}
        return ota.event || root.otaState.event || "-"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Label {
            text: "IVI Head Unit"
            color: "#F2F2F2"
            font.pixelSize: 38
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            SimpleButton { label: "Home"; enabled: false }
            SimpleButton { label: "OTA Status"; onClicked: root.goToOta() }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            radius: 10
            color: "#1E2936"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 20

                Text { text: "Vehicle: " + root.vehicleName(); color: "#DADADA"; font.pixelSize: 18 }
                Text { text: "Version: " + root.currentVersion(); color: "#DADADA"; font.pixelSize: 18 }
                Text { text: "Phase: " + root.phaseText(); color: "#DADADA"; font.pixelSize: 18 }
                Text { text: "Event: " + root.eventText(); color: "#DADADA"; font.pixelSize: 18 }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 16

            Rectangle {
                color: "#1E2936"
                radius: 10
                Layout.fillWidth: true
                Layout.fillHeight: true
                Label { anchors.centerIn: parent; text: "Media"; color: "#DADADA"; font.pixelSize: 26 }
                MouseArea { anchors.fill: parent; onClicked: root.goToMedia() }
            }
            Rectangle {
                color: "#1E2936"
                radius: 10
                Layout.fillWidth: true
                Layout.fillHeight: true
                Label { anchors.centerIn: parent; text: "Navigation"; color: "#DADADA"; font.pixelSize: 26 }
                MouseArea { anchors.fill: parent; onClicked: root.goToNav() }
            }
            Rectangle {
                color: "#1E2936"
                radius: 10
                Layout.fillWidth: true
                Layout.fillHeight: true
                Label { anchors.centerIn: parent; text: "Phone"; color: "#DADADA"; font.pixelSize: 26 }
            }
            Rectangle {
                color: "#1E2936"
                radius: 10
                Layout.fillWidth: true
                Layout.fillHeight: true
                Label { anchors.centerIn: parent; text: "Settings"; color: "#DADADA"; font.pixelSize: 26 }
            }
        }
    }
}
