import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import "pages"
import "services/OtaApi.js" as OtaApi

ApplicationWindow {
    id: root
    width: Screen.width
    height: Screen.height
    visible: true
    visibility: Window.FullScreen
    title: "IVI Head Unit"
    flags: Qt.FramelessWindowHint

    property string baseUrl: "http://127.0.0.1:8080"
    property var otaState: ({
        ts: "2026-01-30T08:15:01+01:00",
        device:     { device_id: "vw-ivi-0076", model: "raspberrypi4", hw_rev: "1.2", serial: "RPI4-8696", current_slot: "B" },
        logVehicle: { brand: "Volkswagen", series: "Golf", segment: "C", fuel: "ICE" },
        ota:        { ota_id: "ota-20260130-319f58", type: "PARTIAL", current_version: "1.2.3", target_version: "1.2.4", phase: "REPORT", event: "OK", attempt: 3 },
        context: {
            power:         { source: "BATTERY", battery: { pct: 78, state: "DISCHARGING", voltage_mv: 5148 } },
            environment:   { temp_c: 56, cpu_load_pct: 29, mem_free_mb: 563, storage_free_mb: 3487 },
            network:       { iface: "wlan0", ip: "192.168.1.130", rssi_dbm: -68, latency_ms: 319, gateway_reachable: true },
            vehicle_state: { driving: true, speed_kph: 98 }
        },
        error:            { code: "NONE", message: "", retryable: false },
        evidence:         { ota_log: ["CHECK OK", "DOWNLOAD OK", "VERIFY OK", "INSTALL OK", "APPLY OK", "POSTCHECK OK", "REPORT SEND status=OK"], journal_log: [], filesystem: [], boot_state: { bootcount: 0, upgrade_available: false } },
        user_interaction: { user_action: "NONE", power_event: "NONE" },
        artifacts:        { screenshot_path: "", log_bundle_path: "" },
        report:           { sent: true, sent_at: "2026-01-30T08:15:02+01:00", server_response: "200 OK" }
    })
    property bool otaBusy: false
    property string errorMessage: ""

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: HomePage {
            otaState: root.otaState
            onGoToOta: stack.push(otaPageComponent)
            onGoToNav: stack.push(navPageComponent)
            onGoToMedia: stack.push(mediaPageComponent)
        }
    }

    Component {
        id: navPageComponent
        NavPage { onBack: stack.pop() }
    }

    Component {
        id: mediaPageComponent
        MediaPage { onBack: stack.pop() }
    }

    Component {
        id: otaPageComponent
        OtaPage {
            baseUrl: root.baseUrl
            otaState: root.otaState
            busy: root.otaBusy
            errorMessage: root.errorMessage
            onBack: stack.pop()
            onRequestStatus: root.fetchStatus()
            onRequestStartUpdate: function(url, targetVersion) {
                root.startUpdate(url, targetVersion)
            }
            onRequestReboot: root.rebootDevice()
        }
    }

    function updateStatus(data) {
        root.otaState = {
            ts:         data.ts || "",
            device:     data.device     || { device_id: "-", model: "-", hw_rev: "-", serial: "-", current_slot: "-" },
            logVehicle: data.log_vehicle || { brand: "-", series: "-", segment: "-", fuel: "-" },
            ota:        data.ota        || { ota_id: "-", type: "-", current_version: "-", target_version: "-", phase: "-", event: "-", attempt: 0 },
            context:    data.context    || {
                power:         { source: "-", battery: { pct: 0, state: "-", voltage_mv: 0 } },
                environment:   { temp_c: 0, cpu_load_pct: 0, mem_free_mb: 0, storage_free_mb: 0 },
                network:       { iface: "-", ip: "-", rssi_dbm: 0, latency_ms: 0, gateway_reachable: false },
                vehicle_state: { driving: false, speed_kph: 0 }
            },
            error:            data.error            || { code: "NONE", message: "", retryable: false },
            evidence:         data.evidence         || { ota_log: [], journal_log: [], filesystem: [], boot_state: { bootcount: 0, upgrade_available: false } },
            user_interaction: data.user_interaction || { user_action: "NONE", power_event: "NONE" },
            artifacts:        data.artifacts        || { screenshot_path: "", log_bundle_path: "" },
            report:           data.report           || { sent: false, sent_at: "", server_response: "" }
        }
    }

    function fetchStatus() {
        OtaApi.getStatus(
            root.baseUrl,
            function(data) {
                root.errorMessage = ""
                root.updateStatus(data)
            },
            function(status, body) {
                root.errorMessage = "Status request failed (" + status + "): " + body
            }
        )
    }

    function startUpdate(url, targetVersion) {
        if (!url || !targetVersion) {
            root.errorMessage = "Bundle URL and Target Version are required."
            return
        }
        root.otaBusy = true
        OtaApi.startUpdate(
            root.baseUrl,
            {
                ota_id: "ota-" + new Date().toISOString().replace(/[-:TZ.]/g, "").slice(0, 12),
                url: url,
                target_version: targetVersion
            },
            function() {
                root.errorMessage = ""
                root.otaBusy = false
                root.fetchStatus()
            },
            function(status, body) {
                root.errorMessage = "Start update failed (" + status + "): " + body
                root.otaBusy = false
            }
        )
    }

    function rebootDevice() {
        OtaApi.reboot(
            root.baseUrl,
            function() {
                root.errorMessage = ""
            },
            function(status, body) {
                root.errorMessage = "Reboot request failed (" + status + "): " + body
            }
        )
    }

    Component.onCompleted: {
        fetchStatus()
    }
}
