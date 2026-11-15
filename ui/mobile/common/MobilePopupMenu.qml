import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.Menu {
    id: control

    implicitWidth: 184
    readonly property real windowHeight: parent?.Window.window?.height ?? 0

    height: Math.min(implicitHeight, Math.max(MobileTheme.touchSize, windowHeight * 0.55))
    padding: MobileTheme.menuPadding
    margins: 8
    spacing: 0
    popupType: Basic.Popup.Item

    background: Rectangle {
        radius: 6
        color: MobileTheme.sidebar
        border.width: 1
        border.color: MobileTheme.line
    }
}
