import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Basic.ComboBox {
    id: control
    implicitHeight: 42
    font.family: DesktopTheme.sans
    font.pixelSize: 14
    palette.text: DesktopTheme.ink
    palette.buttonText: DesktopTheme.ink
    palette.base: DesktopTheme.sidebar
    palette.window: DesktopTheme.sidebar
    palette.highlight: DesktopTheme.ink
    palette.highlightedText: DesktopTheme.paper
    background: Rectangle {
        color: DesktopTheme.sidebar
        border.width: 1
        border.color: control.activeFocus ? DesktopTheme.accent : DesktopTheme.line
    }
}
