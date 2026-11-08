import QtQuick
import QtQuick.Layouts
import UI

ColumnLayout {
    property string caption: ""
    property string title: ""
    spacing: 10

    EditorialText {
        Layout.fillWidth: true
        text: parent.caption
        font.family: DesktopTheme.mono
        font.pixelSize: 11
        font.letterSpacing: 1
        color: DesktopTheme.muted
    }
    EditorialText {
        Layout.fillWidth: true
        text: parent.title
        font.family: DesktopTheme.serif
        font.pixelSize: 46
        font.italic: true
    }
}
