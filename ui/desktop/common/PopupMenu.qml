import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Basic.Menu {
    id: control

    property color backgroundColor: DesktopTheme.sidebar
    property color borderColor: DesktopTheme.line

    implicitWidth: 192
    padding: DesktopTheme.menuPadding
    spacing: 0

    background: Rectangle {
        color: control.backgroundColor
        border.width: 1
        border.color: control.borderColor
    }
}
