import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root
    anchors.fill: parent
    color: "transparent"

    Id5Theme { id: theme }

    property string baseUrl: ""
    property var otaState: ({})
    property bool busy: false
    property string errorMessage: ""
    property string localNowText: ""

    signal back()
    signal requestStatus()
    signal requestStartUpdate(string url, string targetVersion)
    signal requestReboot()

    readonly property var phases: ["DOWNLOAD", "APPLY", "REBOOT"]

    function ota()   { return root.otaState.ota || {} }
    function dev()   { return root.otaState.device || {} }
    function ctx()   { return root.otaState.context || {} }
    function pwr()   { return ctx().power || {} }
    function bat()   { return pwr().battery || {} }
    function net()   { return ctx().network || {} }
    function env()   { return ctx().environment || {} }
    function veh()   { return ctx().vehicle_state || {} }
    function evid()  { return root.otaState.evidence || {} }
    function rep()   { return root.otaState.report || {} }
    function tim()   { return ctx().time || {} }
    function slots() { return root.otaState.slots || [] }

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

    function versionFlowText() {
        var cur = String(ota().current_version || "-").trim()
        var tgt = String(ota().target_version || "").trim()
        if (cur.length === 0)
            cur = "-"
        if (tgt.length === 0 || tgt === "-")
            return cur
        return cur + " -> " + tgt
    }

    Timer {
        interval: 1000
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
        x: parent.width - width * 0.65
        y: -height * 0.45
        color: Qt.rgba(0.30, 0.64, 1.0, 0.16)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SimpleButton { label: "Back"; variant: "ghost"; onClicked: root.back() }
            Text {
                text: "OTA Status"
                color: theme.textPrimary
                font.pixelSize: 26
                font.bold: true
                font.family: theme.fontFamily
            }
            Item { Layout.fillWidth: true }
            Column {
                spacing: 2
                Text {
                    text: dev().device_id || "-"
                    color: theme.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: theme.fontFamily
                }
                Text {
                    text: (dev().model || "-") + "  |  Slot " + (dev().current_slot || "-")
                    color: theme.textSecondary
                    font.pixelSize: 11
                    font.family: theme.fontFamily
                }
                Text {
                    text: "IP: " + (net().ip || "-") + ((net().ip_source && String(net().ip_source).length > 0) ? " (" + net().ip_source + ")" : "")
                    color: theme.textSecondary
                    font.pixelSize: 11
                    font.family: theme.fontFamily
                }
                Text {
                    text: "Time: " + root.currentTimeText()
                    color: theme.textSecondary
                    font.pixelSize: 11
                    font.family: theme.fontFamily
                }
            }
            Rectangle {
                width: 96
                height: 30
                radius: theme.radiusSm
                color: root.busy ? "#3D2D10" : "#143728"
                border.width: 1
                border.color: root.busy ? theme.warn : theme.ok
                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "Working..." : "Idle"
                    color: root.busy ? theme.warn : theme.ok
                    font.pixelSize: 13
                    font.family: theme.fontFamily
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 58
            color: theme.cardSoft
            radius: theme.radiusMd
            border.width: 1
            border.color: theme.stroke

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Repeater {
                    model: root.phases
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 6

                        property bool isDone: index < root.phaseIndex()
                        property bool isCur: index === root.phaseIndex()
                        property bool noPhase: root.phaseIndex() < 0

                        color: isDone ? "#173728" : (isCur ? "#1E416A" : theme.cardSoft)
                        border.color: isCur ? theme.accent : (isDone ? theme.ok : theme.stroke)
                        border.width: isCur ? 2 : 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: noPhase ? "#FFFFFF" : (isDone ? theme.ok : (isCur ? theme.accentSoft : theme.textMuted))
                            font.pixelSize: 12
                            font.bold: isCur
                            font.family: theme.fontFamily
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: theme.card
                radius: theme.radiusLg
                border.width: 1
                border.color: theme.stroke

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        spacing: 8
                        Text { text: ota().ota_id || "-"; color: theme.textSecondary; font.pixelSize: 11; font.family: theme.fontFamily }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: typeLbl.implicitWidth + 10
                            height: 18
                            radius: 3
                            color: ota().type === "PARTIAL" ? "#233B5F" : "#20334E"
                            border.width: 1
                            border.color: theme.stroke
                            Text {
                                id: typeLbl
                                anchors.centerIn: parent
                                text: ota().type || "-"
                                color: theme.accentSoft
                                font.pixelSize: 10
                                font.bold: true
                                font.family: theme.fontFamily
                            }
                        }
                        Text {
                            text: "Attempt " + (ota().attempt || 0)
                            color: theme.textMuted
                            font.pixelSize: 11
                            font.family: theme.fontFamily
                        }
                    }

                    Text { text: "Version"; color: theme.textSecondary; font.pixelSize: 11; font.family: theme.fontFamily }
                    Text {
                        text: root.versionFlowText()
                        color: theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                        font.family: theme.fontFamily
                    }

                    RowLayout {
                        spacing: 8
                        Rectangle {
                            width: phLbl.implicitWidth + 22
                            height: 30
                            radius: 3
                            color: root.phaseIndex() >= 0 ? "#1E416A" : theme.cardSoft
                            border.width: 1
                            border.color: root.phaseIndex() >= 0 ? theme.accent : theme.stroke
                            Text {
                                id: phLbl
                                anchors.centerIn: parent
                                text: ota().phase || "-"
                                color: theme.accentSoft
                                font.pixelSize: 12
                                font.family: theme.fontFamily
                            }
                        }
                        Rectangle {
                            width: evLbl.implicitWidth + 22
                            height: 30
                            radius: 3
                            color: ota().event === "OK" ? "#143728" : (ota().event === "FAIL" ? "#4A1C2A" : theme.cardSoft)
                            border.width: 1
                            border.color: ota().event === "OK" ? theme.ok : (ota().event === "FAIL" ? theme.danger : theme.stroke)
                            Text {
                                id: evLbl
                                anchors.centerIn: parent
                                text: ota().event || "-"
                                color: ota().event === "OK" ? theme.ok : (ota().event === "FAIL" ? theme.danger : theme.textSecondary)
                                font.pixelSize: 12
                                font.family: theme.fontFamily
                            }
                        }
                    }

                    Row {
                        spacing: 8
                        property var err: root.otaState.error || { code: "NONE", message: "" }
                        Rectangle {
                            width: errLbl.implicitWidth + 14
                            height: 22
                            radius: 3
                            color: parent.err.code === "NONE" ? "#143728" : "#4A1C2A"
                            border.width: 1
                            border.color: parent.err.code === "NONE" ? theme.ok : theme.danger
                            Text {
                                id: errLbl
                                anchors.centerIn: parent
                                text: parent.parent.err.code || "NONE"
                                color: parent.parent.err.code === "NONE" ? theme.ok : theme.danger
                                font.pixelSize: 12
                                font.family: theme.fontFamily
                            }
                        }
                        Text {
                            text: (root.otaState.error || {}).message || ""
                            color: theme.danger
                            font.pixelSize: 12
                            font.family: theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                            visible: text.length > 0
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.stroke }

                    Text { text: "Content"; color: theme.textSecondary; font.pixelSize: 11; font.family: theme.fontFamily }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "Current Time"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: root.currentTimeText(); color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                        Column {
                            spacing: 1
                            Text { text: "OTA Event"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: root.otaTimestamp(); color: theme.textSecondary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "Source"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: pwr().source || "-"; color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Battery"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: (bat().pct !== undefined ? bat().pct : 0) + "%  " + (bat().state || "-"); color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "RSSI"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: (net().rssi_dbm || 0) + " dBm"; color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Latency"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: (net().latency_ms || 0) + " ms"; color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                        Column {
                            spacing: 1
                            Text { text: "GW"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text {
                                text: net().gateway_reachable ? "OK" : "FAIL"
                                color: net().gateway_reachable ? theme.ok : theme.danger
                                font.pixelSize: 13
                                font.family: theme.fontFamily
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "CPU"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: (env().cpu_load_pct || 0) + "%"; color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Temp"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: (env().temp_c || 0) + " C"; color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Mem free"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: (env().mem_free_mb || 0) + " MB"; color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            spacing: 1
                            Text { text: "Driving"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text {
                                text: veh().driving ? "YES" : "NO"
                                color: veh().driving ? theme.warn : theme.ok
                                font.pixelSize: 13
                                font.family: theme.fontFamily
                            }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Speed"; color: theme.textMuted; font.pixelSize: 10; font.family: theme.fontFamily }
                            Text { text: (veh().speed_kph || 0) + " kph"; color: theme.textPrimary; font.pixelSize: 13; font.family: theme.fontFamily }
                        }
                    }

                    Text {
                        visible: root.errorMessage.length > 0
                        text: root.errorMessage
                        color: theme.danger
                        font.pixelSize: 12
                        font.family: theme.fontFamily
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: theme.card
                radius: theme.radiusLg
                border.width: 1
                border.color: theme.stroke

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "OTA Log"; color: theme.textSecondary; font.pixelSize: 11; font.family: theme.fontFamily }

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
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "#143728"
                                        border.width: 1
                                        border.color: theme.ok
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            anchors.centerIn: parent
                                            text: "OK"
                                            color: theme.ok
                                            font.pixelSize: 8
                                            font.bold: true
                                            font.family: theme.fontFamily
                                        }
                                    }
                                    Text {
                                        text: modelData
                                        color: theme.textPrimary
                                        font.pixelSize: 14
                                        font.family: theme.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            Text {
                                visible: (evid().ota_log || []).length === 0
                                text: "No log entries"
                                color: theme.textMuted
                                font.pixelSize: 14
                                font.family: theme.fontFamily
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.stroke }

                    Text { text: "Report"; color: theme.textSecondary; font.pixelSize: 11; font.family: theme.fontFamily }
                    Row {
                        spacing: 12
                        Rectangle {
                            width: repLbl.implicitWidth + 14
                            height: 22
                            radius: 3
                            color: rep().sent ? "#143728" : "#3D2D10"
                            border.width: 1
                            border.color: rep().sent ? theme.ok : theme.warn
                            Text {
                                id: repLbl
                                anchors.centerIn: parent
                                text: rep().sent ? "SENT" : "PENDING"
                                color: rep().sent ? theme.ok : theme.warn
                                font.pixelSize: 12
                                font.bold: true
                                font.family: theme.fontFamily
                            }
                        }
                        Text {
                            text: rep().server_response || ""
                            color: theme.textPrimary
                            font.pixelSize: 12
                            font.family: theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text { text: "Slots"; color: theme.textSecondary; font.pixelSize: 11; font.family: theme.fontFamily }
                    Repeater {
                        model: slots()
                        delegate: Row {
                            spacing: 8
                            property bool isActive: modelData.bootname === (dev().current_slot || "")
                            Rectangle {
                                width: slotLabel.implicitWidth + 10
                                height: 22
                                radius: 3
                                color: isActive ? "#1E416A" : theme.cardSoft
                                border.width: 1
                                border.color: isActive ? theme.accent : theme.stroke
                                Text {
                                    id: slotLabel
                                    anchors.centerIn: parent
                                    text: "Slot " + (modelData.bootname || modelData.name)
                                    color: isActive ? theme.accentSoft : theme.textSecondary
                                    font.pixelSize: 11
                                    font.bold: isActive
                                    font.family: theme.fontFamily
                                }
                            }
                            Text {
                                text: modelData.device || ""
                                color: theme.textMuted
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: stateLbl.implicitWidth + 10
                                height: 22
                                radius: 3
                                color: modelData.state === "booted" ? "#143728" : theme.cardSoft
                                border.width: 1
                                border.color: modelData.state === "booted" ? theme.ok : theme.stroke
                                Text {
                                    id: stateLbl
                                    anchors.centerIn: parent
                                    text: modelData.state || "-"
                                    color: modelData.state === "booted" ? theme.ok : theme.textSecondary
                                    font.pixelSize: 11
                                    font.family: theme.fontFamily
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
