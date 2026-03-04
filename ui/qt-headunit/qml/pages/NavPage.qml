import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine 1.10
import "../components"

Rectangle {
    id: root
    anchors.fill: parent
    color: "transparent"

    Id5Theme { id: theme }

    signal back()

    property int zoom: 13
    // Force navigation default to Wolfsburg, DE.
    property real centerLat: 52.4227
    property real centerLon: 10.7865
    property string pageTitle: "Navigation"
    property int mapEpoch: 0
    property string lastLoadError: ""

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }

    function mapUrl(lat, lon, z) {
        var safeZ = Math.round(clamp(z, 3, 18))
        var safeLat = clamp(lat, -85.0, 85.0)
        var safeLon = clamp(lon, -180.0, 180.0)
        return "qrc:/pages/NavMapView.html#lat=" + safeLat.toFixed(6) +
               "&lon=" + safeLon.toFixed(6) +
               "&z=" + safeZ +
               "&v=" + mapEpoch
    }

    function openMap(lat, lon, z) {
        web.url = mapUrl(lat, lon, z)
    }

    function reloadMap() {
        mapEpoch++
        openMap(centerLat, centerLon, zoom)
    }

    Component.onCompleted: openMap(centerLat, centerLon, zoom)

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.bgTop }
            GradientStop { position: 1.0; color: theme.bgBottom }
        }
    }

    Rectangle {
        id: header
        width: parent.width
        height: 64
        color: "#172F50"
        border.width: 1
        border.color: theme.stroke
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            SimpleButton {
                label: "Back"
                variant: "ghost"
                width: 86
                onClicked: root.back()
            }

            Label {
                text: root.pageTitle
                color: theme.textPrimary
                font.pixelSize: 19
                font.bold: true
                font.family: theme.fontFamily
                elide: Text.ElideRight
                Layout.preferredWidth: 260
            }

            Item { Layout.fillWidth: true }

            SimpleButton {
                label: "Center"
                variant: "ghost"
                width: 88
                onClicked: root.reloadMap()
            }

            SimpleButton {
                label: "-"
                variant: "ghost"
                width: 46
                onClicked: {
                    if (root.zoom > 3) {
                        root.zoom--
                        root.openMap(root.centerLat, root.centerLon, root.zoom)
                    }
                }
            }

            Label {
                text: "Z " + root.zoom
                color: theme.textSecondary
                font.pixelSize: 15
                font.family: theme.fontFamily
                Layout.minimumWidth: 40
                horizontalAlignment: Text.AlignHCenter
            }

            SimpleButton {
                label: "+"
                variant: "ghost"
                width: 46
                onClicked: {
                    if (root.zoom < 18) {
                        root.zoom++
                        root.openMap(root.centerLat, root.centerLon, root.zoom)
                    }
                }
            }

            SimpleButton {
                label: "Reload"
                variant: "accent"
                width: 92
                onClicked: root.reloadMap()
            }
        }
    }

    Rectangle {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        radius: theme.radiusLg
        color: theme.card
        border.width: 1
        border.color: theme.stroke
        clip: true

        WebEngineView {
            id: web
            anchors.fill: parent
            url: root.mapUrl(root.centerLat, root.centerLon, root.zoom)

            settings.javascriptEnabled: true
            settings.localStorageEnabled: true
            settings.errorPageEnabled: true
            settings.fullScreenSupportEnabled: true
            settings.accelerated2dCanvasEnabled: true
            settings.webGLEnabled: true
            settings.localContentCanAccessRemoteUrls: true

            onLoadingChanged: function(loadRequest) {
                if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                    root.lastLoadError = "Map load error: " + loadRequest.errorCode + " " + loadRequest.errorString
                    console.log(root.lastLoadError)
                } else if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                    root.lastLoadError = ""
                }
            }
        }
    }

    Rectangle {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        radius: theme.radiusLg
        color: "#0E1C32"
        visible: web.loading
        z: 20
        Text {
            anchors.centerIn: parent
            text: "Loading map..."
            color: theme.textPrimary
            font.pixelSize: 20
            font.family: theme.fontFamily
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 32
        color: "#AA4E1420"
        visible: root.lastLoadError.length > 0
        z: 30
        Text {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.lastLoadError
            color: theme.danger
            font.pixelSize: 12
            font.family: theme.fontFamily
        }
    }
}
