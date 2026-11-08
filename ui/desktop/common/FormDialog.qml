import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import UI

Basic.Dialog {
    id: dialog
    property alias body: bodyScroll.contentData
    parent: Overlay.overlay
    width: Math.min(480, parent.width - 48)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    modal: true
    focus: true
    padding: 24
    topPadding: 18
    spacing: 18

    contentItem: ScrollView {
        id: bodyScroll
        clip: true
        contentWidth: availableWidth
        implicitHeight: Math.min(contentHeight,
                                 Math.max(100, dialog.parent.height - 260))
    }

    background: Rectangle {
        color: DesktopTheme.paper
        border.color: DesktopTheme.ink
        border.width: 1
    }

    header: ColumnLayout {
        spacing: 10
        EditorialText {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 22
            text: "VEXA / УЧЁТ"
            color: DesktopTheme.muted
            font.family: DesktopTheme.mono
            font.pixelSize: 11
        }
        EditorialText {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            text: dialog.title
            font.family: DesktopTheme.serif
            font.pixelSize: 30
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            height: 1
            color: DesktopTheme.ink
        }
    }
}
