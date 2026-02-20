.pragma library

function request(method, url, body, onOk, onErr) {
    var xhr = new XMLHttpRequest()
    xhr.open(method, url)
    xhr.setRequestHeader("Content-Type", "application/json")

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return

        if (xhr.status >= 200 && xhr.status < 300) {
            var parsed = {}
            if (xhr.responseText && xhr.responseText.length > 0) {
                try {
                    parsed = JSON.parse(xhr.responseText)
                } catch (e) {
                    parsed = {}
                }
            }
            onOk(parsed)
            return
        }

        onErr(xhr.status, xhr.responseText || "")
    }

    if (body === undefined || body === null)
        xhr.send()
    else
        xhr.send(JSON.stringify(body))
}

function getStatus(baseUrl, onOk, onErr) {
    request("GET", baseUrl + "/ota/status", null, onOk, onErr)
}

function startUpdate(baseUrl, payload, onOk, onErr) {
    request("POST", baseUrl + "/ota/start", payload, onOk, onErr)
}

function reboot(baseUrl, onOk, onErr) {
    request("POST", baseUrl + "/ota/reboot", {}, onOk, onErr)
}
