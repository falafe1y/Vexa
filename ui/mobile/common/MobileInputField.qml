import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.TextField {
    id: control

    property bool underlined: false

    implicitHeight: underlined ? 44 : MobileTheme.touchSize
    padding: 12
    leftPadding: underlined ? 0 : padding
    rightPadding: underlined ? 0 : padding
    font.family: MobileTheme.sans
    font.pixelSize: 16
    color: MobileTheme.ink
    placeholderTextColor: MobileTheme.muted
    selectionColor: MobileTheme.ink
    selectedTextColor: MobileTheme.paper

    background: Rectangle {
        radius: 6
        color: control.underlined ? "transparent" : MobileTheme.sidebar
        border.width: control.underlined ? 0 : control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? MobileTheme.accent : MobileTheme.line

        Rectangle {
            visible: control.underlined
            anchors.bottom: parent.bottom
            width: parent.width
            height: control.activeFocus ? 2 : 1
            color: control.activeFocus ? MobileTheme.accent : MobileTheme.ink
        }
    }
}
