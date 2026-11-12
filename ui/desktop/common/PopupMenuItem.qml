import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Basic.MenuItem {
    id: control

    property color textColor: DesktopTheme.ink
    property color hoverColor: DesktopTheme.accent
    property color backgroundColor: DesktopTheme.sidebar

    implicitHeight: DesktopTheme.menuItemHeight
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font.family: DesktopTheme.sans
        font.pixelSize: 16
        color: !control.enabled
            ? DesktopTheme.muted
            : (control.hovered || control.highlighted)
                ? control.hoverColor : control.textColor
        verticalAlignment: Text.AlignVCenter
        leftPadding: DesktopTheme.menuTextPadding
        elide: Text.ElideRight
    }



    background: Rectangle {
        color: control.backgroundColor
    }
}
