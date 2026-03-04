import QtQuick 2.15

Rectangle {
    id: btn
    property string label: "Button"
    property string variant: "default" // default | accent | ghost
    property bool active: false
    signal clicked()

    Id5Theme { id: theme }

    width: 172
    height: 46
    radius: theme.radiusMd
    opacity: enabled ? 1.0 : 0.45
    border.width: active ? 2 : 1
    border.color: active ? theme.accentSoft : theme.stroke

    readonly property bool accentLike: (variant === "accent") || active
    readonly property bool ghostLike: variant === "ghost"
    property bool pressedState: false

    gradient: Gradient {
        GradientStop { position: 0.0; color: !btn.enabled ? "#31435F" : (btn.accentLike ? theme.accent : (btn.ghostLike ? "#1A2D4A" : "#1D3A61")) }
        GradientStop { position: 1.0; color: !btn.enabled ? "#2A3A54" : (btn.accentLike ? theme.accentStrong : (btn.ghostLike ? "#10223D" : "#152B49")) }
    }

    Behavior on scale { NumberAnimation { duration: 90 } }
    scale: pressedState ? 0.98 : 1.0

    Text {
        anchors.centerIn: parent
        text: btn.label
        color: theme.textPrimary
        font.pixelSize: 15
        font.bold: btn.accentLike || btn.active
        font.family: theme.fontFamily
    }

    MouseArea {
        anchors.fill: parent
        enabled: btn.enabled
        hoverEnabled: true
        onPressed: btn.pressedState = true
        onReleased: btn.pressedState = false
        onCanceled: btn.pressedState = false
        onClicked: btn.clicked()
    }
}
