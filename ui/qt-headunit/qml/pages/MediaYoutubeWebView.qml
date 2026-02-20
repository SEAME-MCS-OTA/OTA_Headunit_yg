import QtQuick 2.15
import QtWebEngine 1.10

Item {
    id: root
    anchors.fill: parent

    property url currentUrl: web.url
    property string pageTitle: web.title
    property bool canGoBack: web.canGoBack
    property bool canGoForward: web.canGoForward

    function normalizeUrl(raw) {
        var input = String(raw || "").trim()
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

    function loadUrl(raw) {
        var target = normalizeUrl(raw)
        if (target.length === 0)
            return
        web.url = target
    }

    function reloadPage() {
        web.reload()
    }

    function goBack() {
        if (web.canGoBack)
            web.goBack()
    }

    function goForward() {
        if (web.canGoForward)
            web.goForward()
    }

    WebEngineView {
        id: web
        anchors.fill: parent
        url: "https://m.youtube.com"

        settings.javascriptEnabled: true
        settings.localStorageEnabled: true
        settings.fullScreenSupportEnabled: true
        settings.errorPageEnabled: true
        settings.playbackRequiresUserGesture: true
        settings.accelerated2dCanvasEnabled: true
        settings.webGLEnabled: true

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.errorCode !== 0) {
                console.log("WebEngine load error:", loadRequest.errorCode, loadRequest.errorString)
            }
        }
    }
}
