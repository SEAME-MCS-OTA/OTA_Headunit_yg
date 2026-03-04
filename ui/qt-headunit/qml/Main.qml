import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import "pages"
import "components"
import "services/OtaApi.js" as OtaApi

ApplicationWindow {
    id: root
    Id5Theme { id: theme }

    width: Screen.width
    height: Screen.height
    visible: true
    visibility: Window.FullScreen
    title: "IVI Head Unit"
    flags: Qt.FramelessWindowHint
    color: theme.bgTop
    font.family: theme.fontFamily

    property string baseUrl: "http://127.0.0.1:8080"
    property var otaState: ({
        ts: "",
        device:     { device_id: "-", model: "-", current_slot: "-" },
        logVehicle: {},
        ota:        { ota_id: "-", type: "-", current_version: "-", target_version: "-", phase: "-", event: "-", attempt: 0 },
        context: {
            power:         {},
            environment:   {},
            network:       { iface: "wlan0", ip: "-", ip_source: "", rssi_dbm: 0, latency_ms: 0, gateway_reachable: false },
            vehicle_state: {},
            time:          {}
        },
        error:            { code: "NONE", message: "", retryable: false },
        evidence:         { ota_log: [], journal_log: [], filesystem: [], boot_state: {} },
        user_interaction: {},
        artifacts:        {},
        report:           { sent: false, sent_at: "", server_response: "" },
        slots:            []
    })
    property bool otaBusy: false
    property string errorMessage: ""

    Timer {
        id: globalStatusPollTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.fetchStatus()
    }

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
        // API returns a flat structure; map it to the nested otaState shape
        var prevOta  = root.otaState.ota     || {}
        var prevCtx  = root.otaState.context || {}
        var prevEv   = root.otaState.evidence || {}
        var dataCtx  = data.context || {}
        var dataNet  = dataCtx.network || {}
        var prevNet  = prevCtx.network || {}
        
        function isValidIpv4(v) {
            var s = String(v || "").trim()
            var m = s.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/)
            if (!m)
                return false
            for (var i = 1; i <= 4; i++) {
                var n = parseInt(m[i], 10)
                if (isNaN(n) || n < 0 || n > 255)
                    return false
            }
            return true
        }

        var resolvedIp = data.ip_address || data.ip || dataNet.ip || prevNet.ip || "-"
        resolvedIp = String(resolvedIp).trim()
        var prevIp = String(prevNet.ip || "").trim()
        if (!isValidIpv4(resolvedIp)) {
            if (isValidIpv4(prevIp))
                resolvedIp = prevIp
            else
                resolvedIp = "-"
        }

        var resolvedIpSource = data.ip_source || dataNet.ip_source || prevNet.ip_source || ""
        resolvedIpSource = String(resolvedIpSource).trim()

        var resolvedCurrentVersion = String(data.current_version || "").trim()
        var prevCurrentVersion = String(prevOta.current_version || "").trim()
        if (resolvedCurrentVersion.length === 0 || resolvedCurrentVersion === "-")
            resolvedCurrentVersion = (prevCurrentVersion.length > 0 ? prevCurrentVersion : "-")

        var resolvedTargetVersion = String(data.target_version || "").trim()
        var prevTargetVersion = String(prevOta.target_version || "").trim()
        if (resolvedTargetVersion.length === 0 || resolvedTargetVersion === "-")
            resolvedTargetVersion = (prevTargetVersion.length > 0 ? prevTargetVersion : "-")

        root.otaState = {
            ts: data.ts || "",
            device: {
                device_id:    data.device_id    || "-",
                model:        data.compatible   || "raspberrypi4",
                current_slot: data.current_slot || "-"
            },
            logVehicle: root.otaState.logVehicle || {},
            ota: {
                ota_id:          data.ota_id             || prevOta.ota_id || "-",
                type:            "-",
                current_version: resolvedCurrentVersion,
                target_version:  resolvedTargetVersion,
                phase:           data.phase              || "-",
                event:           data.event              || "-",
                attempt:         0
            },
            context: {
                power:         prevCtx.power         || {},
                environment:   prevCtx.environment   || {},
                network: {
                    iface:             data.iface || dataNet.iface || prevNet.iface || "wlan0",
                    ip:                resolvedIp,
                    ip_source:         resolvedIpSource,
                    rssi_dbm:          dataNet.rssi_dbm !== undefined ? dataNet.rssi_dbm : 0,
                    latency_ms:        dataNet.latency_ms !== undefined ? dataNet.latency_ms : 0,
                    gateway_reachable: !!dataNet.gateway_reachable
                },
                vehicle_state: prevCtx.vehicle_state || {},
                time: {
                    local: (dataCtx.time && dataCtx.time.local) ? dataCtx.time.local : (data.ts || "")
                }
            },
            error: data.last_error
                ? { code: data.last_error, message: data.last_error, retryable: false }
                : { code: "NONE", message: "", retryable: false },
            evidence: {
                ota_log: data.ota_log || prevEv.ota_log || [],
                journal_log: prevEv.journal_log || [],
                filesystem: prevEv.filesystem || [],
                boot_state: prevEv.boot_state || {}
            },
            user_interaction: root.otaState.user_interaction || {},
            artifacts:        root.otaState.artifacts        || {},
            report:           root.otaState.report           || { sent: false },
            slots:            data.slots || []
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
