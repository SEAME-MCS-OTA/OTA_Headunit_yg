import QtQuick 2.15

Rectangle {
    id: btn
    property string label: "Button"
    signal clicked()

    width: 168
    height: 44
    radius: 6
    color: enabled ? "#2B3645" : "#3A4352"
    opacity: enabled ? 1.0 : 0.45

    Text {
        anchors.centerIn: parent
        text: btn.label
        color: "#F2F2F2"
        font.pixelSize: 16
    }

    MouseArea {
        anchors.fill: parent
        enabled: btn.enabled
        onClicked: btn.clicked()
    }
}
