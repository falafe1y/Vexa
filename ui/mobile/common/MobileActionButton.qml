import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.Button {
    id: control

    property bool outlined: true
    property bool danger: false

    readonly property bool filled: !flat && !outlined
    readonly property color actionColor: danger ? MobileTheme.accent : MobileTheme.ink

    padding: 10
    implicitHeight: MobileTheme.touchSize
    implicitWidth: Math.max(MobileTheme.touchSize, implicitContentWidth + leftPadding + rightPadding)
    font.family: MobileTheme.mono
    font.pixelSize: 12
    font.bold: true
    opacity: enabled ? 1 : 0.48

    contentItem: MobileEditorialText {
        text: control.text
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        color: control.filled ? MobileTheme.sidebar : control.actionColor
    }

    background: Rectangle {
        radius: 6
        color: control.filled
            ? (control.down ? Qt.darker(control.actionColor, 1.25) : control.actionColor)
            : (control.down ? MobileTheme.soft : "transparent")
        border.width: control.visualFocus ? 2 : control.flat ? 0 : 1
        border.color: control.visualFocus ? MobileTheme.accent : control.actionColor
    }
}
