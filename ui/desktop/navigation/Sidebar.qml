import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import UI

Rectangle {
    id: sidebar
    property int currentPage: 0
    signal pageRequested(int page)
    color: DesktopTheme.sidebar

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: DesktopTheme.ink
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        EditorialText {
            Layout.fillWidth: true
            Layout.topMargin: 12
            text: "Vexa."
            font.family: DesktopTheme.serif
            font.pixelSize: 46
            font.italic: true
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.bottomMargin: 24
            height: 1
            color: DesktopTheme.ink
        }

        NavLink {
            Layout.fillWidth: true
            number: "01"
            text: "Дашборд"
            selected: sidebar.currentPage === 0
            onClicked: sidebar.pageRequested(0)
        }
        NavLink {
            Layout.fillWidth: true
            number: "02"
            text: "Категории"
            selected: sidebar.currentPage === 1
            onClicked: sidebar.pageRequested(1)
        }

        Item { Layout.fillHeight: true }

        EditorialText {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            text: "Порядок\nв личных финансах."
            font.family: DesktopTheme.serif
            font.pixelSize: 23
            font.italic: true
            wrapMode: Text.WordWrap
        }

        NavLink {
            Layout.fillWidth: true
            number: "03"
            text: "Настройки"
            selected: sidebar.currentPage === 2
            onClicked: sidebar.pageRequested(2)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            height: 1
            color: DesktopTheme.ink
        }
        EditorialText {
            Layout.fillWidth: true
            text: "ЛОКАЛЬНЫЙ УЧЁТ"
            font.family: DesktopTheme.mono
            font.pixelSize: 10
            color: DesktopTheme.muted
        }
    }

    component NavLink: Basic.Button {
        id: link
        property string number: ""
        property bool selected: false
        implicitHeight: 46
        padding: 0
        hoverEnabled: true
        contentItem: RowLayout {
            spacing: 12
            EditorialText {
                Layout.preferredWidth: 22
                text: link.number
                color: link.selected ? DesktopTheme.accent : DesktopTheme.muted
                font.family: DesktopTheme.mono
                font.pixelSize: 11
            }
            EditorialText {
                Layout.fillWidth: true
                text: link.text
                font.bold: link.selected
                color: link.hovered ? DesktopTheme.accent : DesktopTheme.ink
            }
        }
        background: Item {
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                visible: link.selected
                color: DesktopTheme.ink
            }
        }
    }
}
