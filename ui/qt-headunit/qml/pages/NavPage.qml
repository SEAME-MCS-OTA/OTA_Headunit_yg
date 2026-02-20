import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine 1.10
import "../components"

Rectangle {
    id: root
    anchors.fill: parent
    color: "#0E1116"

    signal back()

    property int zoom: 13
    property real centerLat: 37.5665
    property real centerLon: 126.9780
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
        id: header
        width: parent.width
        height: 56
        color: "#121820"
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            SimpleButton {
                label: "Back"
                width: 80
                onClicked: root.back()
            }

            Label {
                text: root.pageTitle
                color: "#F2F2F2"
                font.pixelSize: 18
                elide: Text.ElideRight
                Layout.preferredWidth: 220
            }

            Item { Layout.fillWidth: true }

            SimpleButton {
                label: "Home"
                width: 84
                onClicked: root.reloadMap()
            }

            SimpleButton {
                label: "-"
                width: 44
                onClicked: {
                    if (root.zoom > 3) {
                        root.zoom--
                        root.openMap(root.centerLat, root.centerLon, root.zoom)
                    }
                }
            }

            Label {
                text: "Z " + root.zoom
                color: "#DADADA"
                font.pixelSize: 15
                Layout.minimumWidth: 38
                horizontalAlignment: Text.AlignHCenter
            }

            SimpleButton {
                label: "+"
                width: 44
                onClicked: {
                    if (root.zoom < 18) {
                        root.zoom++
                        root.openMap(root.centerLat, root.centerLon, root.zoom)
                    }
                }
            }

            SimpleButton {
                label: "Reload"
                width: 84
                onClicked: root.reloadMap()
            }
        }
    }

    WebEngineView {
        id: web
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        url: root.mapUrl(root.centerLat, root.centerLon, root.zoom)

        settings.javascriptEnabled: true
        settings.localStorageEnabled: true
        settings.errorPageEnabled: true
        settings.fullScreenSupportEnabled: true
        settings.accelerated2dCanvasEnabled: true
        settings.webGLEnabled: true
        settings.localContentCanAccessRemoteUrls: true

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.errorCode !== 0) {
                root.lastLoadError = "Map load error: " + loadRequest.errorCode + " " + loadRequest.errorString
                console.log(root.lastLoadError)
            } else if (!web.loading) {
                root.lastLoadError = ""
            }
        }
    }

    Rectangle {
        anchors.fill: web
        color: "#0E1116"
        visible: web.loading
        z: 20
        Text {
            anchors.centerIn: parent
            text: "Loading map..."
            color: "#DADADA"
            font.pixelSize: 20
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 28
        color: "#AA3A1010"
        visible: root.lastLoadError.length > 0
        z: 30
        Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.lastLoadError
            color: "#FFB0B0"
            font.pixelSize: 12
        }
    }
}
