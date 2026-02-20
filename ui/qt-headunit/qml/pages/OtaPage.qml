import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root
    anchors.fill: parent
    color: "#121820"

    property string baseUrl: ""
    property var otaState: ({})
    property bool busy: false
    property string errorMessage: ""
    property string localNowText: ""

    signal back()
    signal requestStatus()
    signal requestStartUpdate(string url, string targetVersion)
    signal requestReboot()

    readonly property var phases: ["CHECK", "DOWNLOAD", "VERIFY", "INSTALL", "APPLY", "POSTCHECK", "REPORT"]

    // Helpers to safely access nested fields
    function ota()     { return root.otaState.ota     || {} }
    function dev()     { return root.otaState.device  || {} }
    function ctx()     { return root.otaState.context || {} }
    function pwr()     { return ctx().power       || {} }
    function bat()     { return pwr().battery     || {} }
    function net()     { return ctx().network     || {} }
    function env()     { return ctx().environment || {} }
    function veh()     { return ctx().vehicle_state || {} }
    function evid()    { return root.otaState.evidence || {} }
    function rep()     { return root.otaState.report   || {} }
    function tim()     { return ctx().time || {} }

    function pad2(v) {
        return (v < 10 ? "0" : "") + v
    }

    function formatNow(dt) {
        return dt.getFullYear() + "-" +
               pad2(dt.getMonth() + 1) + "-" +
               pad2(dt.getDate()) + " " +
               pad2(dt.getHours()) + ":" +
               pad2(dt.getMinutes()) + ":" +
               pad2(dt.getSeconds())
    }

    function parseIso(raw) {
        var s = String(raw || "").trim()
        if (s.length === 0)
            return null
        var normalized = s.replace(" ", "T")
        var d = new Date(normalized)
        if (!isNaN(d.getTime()))
            return d
        return null
    }

    function extractIsoWallClock(raw) {
        var s = String(raw || "").trim()
        if (s.length === 0)
            return ""
        var m = s.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})/)
        if (m && m.length >= 3)
            return m[1] + " " + m[2]
        return ""
    }

    function formatTimeString(raw) {
        var wallClock = extractIsoWallClock(raw)
        if (wallClock.length > 0)
            return wallClock
        var d = parseIso(raw)
        if (d)
            return formatNow(d)
        return String(raw || "")
    }

    function currentTimeText() {
        if (tim().local && String(tim().local).length > 0)
            return formatTimeString(tim().local)
        if (root.otaState.ts && String(root.otaState.ts).length > 0)
            return formatTimeString(root.otaState.ts)
        return root.localNowText
    }

    function otaTimestamp() {
        if (root.otaState.ts && String(root.otaState.ts).length > 0)
            return String(root.otaState.ts)
        return "-"
    }

    function phaseIndex() {
        return phases.indexOf(ota().phase || "")
    }

    function progressValue() {
        var idx = phaseIndex()
        if (idx < 0) return 0
        return (idx + 1) / phases.length
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: root.requestStatus()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.localNowText = root.formatNow(new Date())
    }

    Component.onCompleted: {
        root.localNowText = root.formatNow(new Date())
        root.requestStatus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        // === Header ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SimpleButton { label: "Back"; onClicked: root.back() }
            Text {
                text: "OTA Status"
                color: "#F2F2F2"; font.pixelSize: 26; font.bold: true
            }
            Item { Layout.fillWidth: true }
            Column {
                spacing: 2
                Text {
                    text: dev().device_id || "-"
                    color: "#DADADA"; font.pixelSize: 13; font.bold: true
                }
                Text {
                    text: (dev().model || "-") + "  |  Slot " + (dev().current_slot || "-")
                    color: "#7A8699"; font.pixelSize: 11
                }
                Text {
                    text: "Time: " + root.currentTimeText()
                    color: "#7A8699"; font.pixelSize: 11
                }
            }
            Rectangle {
                width: 90; height: 28; radius: 4
                color: root.busy ? "#3A3010" : "#0D2A1A"
                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "Working..." : "Idle"
                    color: root.busy ? "#F5D06F" : "#7AE08E"
                    font.pixelSize: 13
                }
            }
        }

        // === Phase pipeline ===
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: "#1A2230"
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 3

                Repeater {
                    model: root.phases
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        radius: 4

                        property bool isDone: index < root.phaseIndex()
                        property bool isCur:  index === root.phaseIndex()

                        color: isDone ? "#0D3A1A" : isCur ? "#1A3A5A" : "#1A2230"
                        border.color: isCur ? "#4A9ADA" : isDone ? "#2ACA5A" : "#263040"
                        border.width: isCur ? 2 : 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: isDone ? "#4ADA6A" : isCur ? "#4AC8FF" : "#556070"
                            font.pixelSize: 10
                            font.bold: isCur
                        }
                    }
                }
            }
        }

        // === Main area ===
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // ---- Left panel ----
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#1E2936"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    // OTA info row
                    RowLayout {
                        spacing: 8
                        Text { text: ota().ota_id || "-"; color: "#7A8699"; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: typeLbl.implicitWidth + 10; height: 18; radius: 3
                            color: ota().type === "PARTIAL" ? "#2A1A3A" : "#1A2A3A"
                            Text {
                                id: typeLbl
                                anchors.centerIn: parent
                                text: ota().type || "-"
                                color: "#AAAAFF"; font.pixelSize: 10; font.bold: true
                            }
                        }
                        Text {
                            text: "Attempt " + (ota().attempt || 0)
                            color: "#556070"; font.pixelSize: 11
                        }
                    }

                    // Version
                    Text { text: "Version"; color: "#7A8699"; font.pixelSize: 11 }
                    Text {
                        text: (ota().current_version || "?") + "   ->   " + (ota().target_version || "?")
                        color: "#F2F2F2"; font.pixelSize: 18; font.bold: true
                    }

                    // Phase + Event
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            width: phLbl.implicitWidth + 14; height: 22; radius: 3
                            color: root.phaseIndex() >= 0 ? "#1A3A5A" : "#1A2230"
                            border.color: root.phaseIndex() >= 0 ? "#4A9ADA" : "#263040"
                            border.width: 1
                            Text {
                                id: phLbl; anchors.centerIn: parent
                                text: ota().phase || "-"
                                color: "#4AC8FF"; font.pixelSize: 12
                            }
                        }
                        Rectangle {
                            width: evLbl.implicitWidth + 14; height: 22; radius: 3
                            color: ota().event === "OK" ? "#0D2A1A" : ota().event === "FAIL" ? "#3A1010" : "#1A2230"
                            Text {
                                id: evLbl; anchors.centerIn: parent
                                text: ota().event || "-"
                                color: ota().event === "OK" ? "#7AE08E" : ota().event === "FAIL" ? "#FF8B8B" : "#7A8699"
                                font.pixelSize: 12
                            }
                        }
                    }

                    // Error
                    Row {
                        spacing: 8
                        property var err: root.otaState.error || { code: "NONE", message: "" }
                        Rectangle {
                            width: errLbl.implicitWidth + 14; height: 22; radius: 3
                            color: parent.err.code === "NONE" ? "#0D2A1A" : "#3A1010"
                            Text {
                                id: errLbl; anchors.centerIn: parent
                                text: parent.parent.err.code || "NONE"
                                color: parent.parent.err.code === "NONE" ? "#7AE08E" : "#FF8B8B"
                                font.pixelSize: 12
                            }
                        }
                        Text {
                            text: (root.otaState.error || {}).message || ""
                            color: "#FF8B8B"; font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: text.length > 0
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#263040" }

                    // Content
                    Text { text: "Content"; color: "#7A8699"; font.pixelSize: 11 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "Current Time"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: root.currentTimeText(); color: "#DADADA"; font.pixelSize: 13 }
                        }
                        Column {
                            spacing: 1
                            Text { text: "OTA Event"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: root.otaTimestamp(); color: "#7A8699"; font.pixelSize: 13 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "Source"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: pwr().source || "-"; color: "#DADADA"; font.pixelSize: 13 }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Battery"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: (bat().pct !== undefined ? bat().pct : 0) + "%  " + (bat().state || "-"); color: "#DADADA"; font.pixelSize: 13 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "RSSI"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: (net().rssi_dbm || 0) + " dBm"; color: "#DADADA"; font.pixelSize: 13 }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Latency"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: (net().latency_ms || 0) + " ms"; color: "#DADADA"; font.pixelSize: 13 }
                        }
                        Column {
                            spacing: 1
                            Text { text: "GW"; color: "#556070"; font.pixelSize: 10 }
                            Text {
                                text: net().gateway_reachable ? "OK" : "FAIL"
                                color: net().gateway_reachable ? "#7AE08E" : "#FF8B8B"; font.pixelSize: 13
                            }
                        }
                    }

                    // Environment
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "CPU"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: (env().cpu_load_pct || 0) + "%"; color: "#DADADA"; font.pixelSize: 13 }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Temp"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: (env().temp_c || 0) + " C"; color: "#DADADA"; font.pixelSize: 13 }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Mem free"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: (env().mem_free_mb || 0) + " MB"; color: "#DADADA"; font.pixelSize: 13 }
                        }
                    }

                    // Vehicle state
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "Driving"; color: "#556070"; font.pixelSize: 10 }
                            Text {
                                text: veh().driving ? "YES" : "NO"
                                color: veh().driving ? "#F5D06F" : "#7AE08E"; font.pixelSize: 13
                            }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Speed"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: (veh().speed_kph || 0) + " kph"; color: "#DADADA"; font.pixelSize: 13 }
                        }
                    }

                    // API error
                    Text {
                        visible: root.errorMessage.length > 0
                        text: root.errorMessage
                        color: "#FF8B8B"; font.pixelSize: 12
                        Layout.fillWidth: true; wrapMode: Text.Wrap
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ---- Right panel: OTA Log + Report ----
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#1E2936"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "OTA Log"; color: "#7A8699"; font.pixelSize: 11 }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: logCol.implicitHeight

                        Column {
                            id: logCol
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: evid().ota_log || []
                                delegate: Row {
                                    spacing: 8
                                    Rectangle {
                                        width: 20; height: 20; radius: 10; color: "#0D2A1A"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            anchors.centerIn: parent
                                            text: "OK"; color: "#4ADA6A"
                                            font.pixelSize: 8; font.bold: true
                                        }
                                    }
                                    Text {
                                        text: modelData
                                        color: "#DADADA"; font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            Text {
                                visible: (evid().ota_log || []).length === 0
                                text: "No log entries"
                                color: "#556070"; font.pixelSize: 14
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#263040" }

                    // Report status
                    Text { text: "Report"; color: "#7A8699"; font.pixelSize: 11 }
                    Row {
                        spacing: 12
                        Rectangle {
                            width: repLbl.implicitWidth + 14; height: 22; radius: 3
                            color: rep().sent ? "#0D2A1A" : "#3A2010"
                            Text {
                                id: repLbl; anchors.centerIn: parent
                                text: rep().sent ? "SENT" : "PENDING"
                                color: rep().sent ? "#7AE08E" : "#F5D06F"
                                font.pixelSize: 12; font.bold: true
                            }
                        }
                        Text {
                            text: rep().server_response || ""
                            color: "#DADADA"; font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Boot state
                    Row {
                        spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "Bootcount"; color: "#556070"; font.pixelSize: 10 }
                            Text { text: "" + ((evid().boot_state || {}).bootcount || 0); color: "#DADADA"; font.pixelSize: 13 }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Upgrade avail"; color: "#556070"; font.pixelSize: 10 }
                            Text {
                                text: (evid().boot_state || {}).upgrade_available ? "YES" : "NO"
                                color: "#DADADA"; font.pixelSize: 13
                            }
                        }
                    }
                }
            }
        }

        // === Controls ===
        Rectangle {
            Layout.fillWidth: true
            height: 96
            color: "#1A2230"
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SimpleInput { id: urlField; Layout.fillWidth: true; placeholder: "Bundle URL" }
                    SimpleInput { id: targetField; width: 170; placeholder: "Target Version" }
                }

                RowLayout {
                    spacing: 8
                    SimpleButton {
                        label: "Start OTA"
                        enabled: !root.busy
                        onClicked: root.requestStartUpdate(urlField.value, targetField.value)
                    }
                    SimpleButton {
                        label: "Check Status"
                        enabled: !root.busy
                        onClicked: root.requestStatus()
                    }
                    SimpleButton {
                        label: "Reboot"
                        enabled: !root.busy
                        onClicked: root.requestReboot()
                    }
                }
            }
        }
    }
}
