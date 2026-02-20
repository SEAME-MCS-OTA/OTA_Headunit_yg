import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root
    anchors.fill: parent
    color: "#0F0F0F"

    signal back()

    property string currentUrl: "https://m.youtube.com"
    property string pageTitle: "YouTube"

    readonly property bool webReady: webLoader.status === Loader.Ready
    readonly property bool canGoBack: webReady && webLoader.item && webLoader.item.canGoBack
    readonly property bool canGoForward: webReady && webLoader.item && webLoader.item.canGoForward

    function normalizeInput(raw) {
        var input = (raw || "").trim()
        if (input.length === 0)
            return ""
        if (input.indexOf("://") >= 0)
            return input
        if (input.indexOf(" ") >= 0)
            return "https://www.youtube.com/results?search_query=" + encodeURIComponent(input)
        if (input.indexOf(".") >= 0)
            return "https://" + input
        return "https://www.youtube.com/results?search_query=" + encodeURIComponent(input)
    }

    function openInput(raw) {
        var target = normalizeInput(raw)
        if (target.length === 0)
            return
        currentUrl = target
        addressField.text = target
        if (webReady && webLoader.item && webLoader.item.loadUrl)
            webLoader.item.loadUrl(target)
    }

    function syncFromWebView() {
        if (!webReady || !webLoader.item)
            return
        var urlText = String(webLoader.item.currentUrl || "")
        if (urlText.length > 0) {
            currentUrl = urlText
            addressField.text = urlText
        }
        var title = String(webLoader.item.pageTitle || "")
        pageTitle = title.length > 0 ? title : "YouTube"
    }

    Rectangle {
        id: header
        width: parent.width
        height: 56
        color: "#1A1A1A"
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            SimpleButton {
                label: "Back"
                width: 80
                onClicked: root.back()
            }

            Label {
                text: root.pageTitle
                color: "#F2F2F2"
                font.pixelSize: 15
                elide: Text.ElideRight
                Layout.preferredWidth: 220
            }

            TextField {
                id: addressField
                Layout.fillWidth: true
                text: root.currentUrl
                placeholderText: "YouTube URL or search text"
                color: "#F2F2F2"
                selectByMouse: true
                onAccepted: root.openInput(text)
                background: Rectangle {
                    radius: 4
                    color: "#111111"
                    border.width: 1
                    border.color: "#444444"
                }
            }

            SimpleButton {
                label: "Go"
                width: 68
                onClicked: root.openInput(addressField.text)
            }

            SimpleButton {
                label: "Home"
                width: 82
                onClicked: root.openInput("https://m.youtube.com")
            }

            SimpleButton {
                label: "Prev"
                width: 72
                enabled: root.canGoBack
                onClicked: if (webLoader.item) webLoader.item.goBack()
            }

            SimpleButton {
                label: "Next"
                width: 72
                enabled: root.canGoForward
                onClicked: if (webLoader.item) webLoader.item.goForward()
            }

            SimpleButton {
                label: "Reload"
                width: 82
                enabled: root.webReady
                onClicked: if (webLoader.item) webLoader.item.reloadPage()
            }
        }
    }

    Loader {
        id: webLoader
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        source: "MediaYoutubeWebView.qml"
        onStatusChanged: {
            if (status === Loader.Ready && item) {
                item.loadUrl(root.currentUrl)
            } else if (status === Loader.Error) {
                root.pageTitle = "YouTube unavailable"
            }
        }
    }

    Connections {
        target: root.webReady ? webLoader.item : null
        function onCurrentUrlChanged() { root.syncFromWebView() }
        function onPageTitleChanged() { root.syncFromWebView() }
    }

    Rectangle {
        anchors.fill: webLoader
        color: "#000000"
        visible: webLoader.status === Loader.Loading
        z: 20
        Text {
            anchors.centerIn: parent
            text: "Loading browser..."
            color: "#CCCCCC"
            font.pixelSize: 20
        }
    }

    Rectangle {
        anchors.fill: webLoader
        color: "#0F0F0F"
        visible: webLoader.status === Loader.Error
        z: 20

        Column {
            anchors.centerIn: parent
            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Web engine module is not available."
                color: "#E0E0E0"
                font.pixelSize: 22
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Install qtwebengine and rebuild the image."
                color: "#B0B0B0"
                font.pixelSize: 16
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Also check device time and internet connection."
                color: "#B0B0B0"
                font.pixelSize: 16
            }
        }
    }
}
