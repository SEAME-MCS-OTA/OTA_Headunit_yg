import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: inputWrap
    property string placeholder: ""
    property alias value: input.text

    color: "#0E1116"
    radius: 6
    height: 40
    Layout.fillWidth: true

    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: 8
        color: "#F2F2F2"
        font.pixelSize: 15
        selectionColor: "#2B3645"
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: inputWrap.placeholder
        color: "#7A8699"
        visible: input.text.length === 0
        font.pixelSize: 15
    }
}
