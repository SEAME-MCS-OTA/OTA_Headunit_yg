import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: inputWrap
    property string placeholder: ""
    property alias value: input.text

    Id5Theme { id: theme }

    color: "#112845"
    radius: theme.radiusSm
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? theme.accentSoft : theme.stroke
    height: 40
    Layout.fillWidth: true

    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: 9
        color: theme.textPrimary
        font.pixelSize: 15
        font.family: theme.fontFamily
        selectionColor: "#2F568D"
        selectedTextColor: "#FFFFFF"
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: inputWrap.placeholder
        color: theme.textMuted
        visible: input.text.length === 0
        font.pixelSize: 15
        font.family: theme.fontFamily
    }
}
