import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Rectangle {
    id: root
    anchors.fill: parent
    color: "transparent"

    Id5Theme { id: theme }

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
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.bgTop }
            GradientStop { position: 1.0; color: theme.bgBottom }
        }
    }

    Rectangle {
        id: header
        width: parent.width
        height: 66
        color: "#172F50"
        border.width: 1
        border.color: theme.stroke
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            SimpleButton {
                label: "Back"
                variant: "ghost"
                width: 84
                onClicked: root.back()
            }

            Label {
                text: root.pageTitle
                color: theme.textPrimary
                font.pixelSize: 16
                font.bold: true
                font.family: theme.fontFamily
                elide: Text.ElideRight
                Layout.preferredWidth: 240
            }

            TextField {
                id: addressField
                Layout.fillWidth: true
                text: root.currentUrl
                placeholderText: "YouTube URL or search text"
                color: theme.textPrimary
                font.family: theme.fontFamily
                selectByMouse: true
                onAccepted: root.openInput(text)
                background: Rectangle {
                    radius: theme.radiusSm
                    color: "#10233F"
                    border.width: 1
                    border.color: addressField.activeFocus ? theme.accentSoft : theme.stroke
                }
            }

            SimpleButton {
                label: "Go"
                variant: "accent"
                width: 66
                onClicked: root.openInput(addressField.text)
            }

            SimpleButton {
                label: "Home"
                variant: "ghost"
                width: 80
                onClicked: root.openInput("https://m.youtube.com")
            }

            SimpleButton {
                label: "Prev"
                variant: "ghost"
                width: 72
                enabled: root.canGoBack
                onClicked: if (webLoader.item) webLoader.item.goBack()
            }

            SimpleButton {
                label: "Next"
                variant: "ghost"
                width: 72
                enabled: root.canGoForward
                onClicked: if (webLoader.item) webLoader.item.goForward()
            }

            SimpleButton {
                label: "Reload"
                variant: "ghost"
                width: 86
                enabled: root.webReady
                onClicked: if (webLoader.item) webLoader.item.reloadPage()
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

        Loader {
            id: webLoader
            anchors.fill: parent
            source: "MediaYoutubeWebView.qml"
            onStatusChanged: {
                if (status === Loader.Ready && item) {
                    item.loadUrl(root.currentUrl)
                } else if (status === Loader.Error) {
                    root.pageTitle = "YouTube unavailable"
                }
            }
        }
    }

    Connections {
        target: root.webReady ? webLoader.item : null
        function onCurrentUrlChanged() { root.syncFromWebView() }
        function onPageTitleChanged() { root.syncFromWebView() }
    }

    Rectangle {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        radius: theme.radiusLg
        color: "#0E1C32"
        visible: webLoader.status === Loader.Loading
        z: 20
        Text {
            anchors.centerIn: parent
            text: "Loading browser..."
            color: theme.textPrimary
            font.pixelSize: 20
            font.family: theme.fontFamily
        }
    }

    Rectangle {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        radius: theme.radiusLg
        color: "#0B182C"
        visible: webLoader.status === Loader.Error
        z: 20

        Column {
            anchors.centerIn: parent
            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Web engine module is not available."
                color: theme.textPrimary
                font.pixelSize: 22
                font.family: theme.fontFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Install qtwebengine and rebuild the image."
                color: theme.textSecondary
                font.pixelSize: 16
                font.family: theme.fontFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Also check device time and internet connection."
                color: theme.textSecondary
                font.pixelSize: 16
                font.family: theme.fontFamily
            }
        }
    }
}
