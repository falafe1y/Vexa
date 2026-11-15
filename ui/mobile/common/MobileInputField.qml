import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.TextField {
    id: control

    implicitHeight: MobileTheme.touchSize
    padding: 12
    font.family: MobileTheme.sans
    font.pixelSize: 16
    color: MobileTheme.ink
    placeholderTextColor: MobileTheme.muted
    selectionColor: MobileTheme.ink
    selectedTextColor: MobileTheme.paper

    background: Rectangle {
        radius: 6
        color: MobileTheme.sidebar
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? MobileTheme.accent : MobileTheme.line
    }
}
