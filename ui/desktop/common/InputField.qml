import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Basic.TextField {
    id: control
    implicitHeight: 42
    padding: 12
    font.family: DesktopTheme.sans
    font.pixelSize: 14
    color: DesktopTheme.ink
    placeholderTextColor: DesktopTheme.muted
    selectionColor: DesktopTheme.ink
    selectedTextColor: DesktopTheme.paper
    background: Rectangle {
        color: DesktopTheme.sidebar
        border.width: 1
        border.color: control.activeFocus ? DesktopTheme.accent : DesktopTheme.line
    }
}
