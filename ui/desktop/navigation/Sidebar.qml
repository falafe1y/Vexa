import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Rectangle {
    id: sidebar
    property int currentPage: 0
    signal pageRequested(int page)
    readonly property bool rail: width <= 72
    readonly property bool shortWindow: height <= 800 && !rail
    readonly property int pad: rail ? 12 : width <= 208 ? 16 : 24
    readonly property int topPad: rail ? 20 : shortWindow ? 16 : 24
    color: DesktopTheme.sidebar
    clip: true

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: DesktopTheme.ink }

    Item {
        id: brand
        x: sidebar.pad; y: sidebar.topPad
        width: parent.width - sidebar.pad * 2
        height: sidebar.rail ? 80 : sidebar.shortWindow ? 96 : 104
        EditorialText {
            width: parent.width; height: sidebar.rail ? 40 : 64
            text: "Vexa."
            font.family: "Gelasio"; font.italic: true; font.bold: true
            font.pixelSize: sidebar.rail ? 20 : 48
            font.letterSpacing: sidebar.rail ? -1 : -2
            fontSizeMode: Text.Fit; minimumPixelSize: sidebar.rail ? 16 : 30
        }
        Rectangle { y: sidebar.rail ? 64 : 80; width: parent.width; height: 1; color: DesktopTheme.ink }
    }
    Column {
        id: navigation
        x: sidebar.pad; y: brand.y + brand.height
        width: parent.width - sidebar.pad * 2
        Repeater {
            model: ["Обзор", "Категории", "Цели", "Заметки", "Траектория", "Бюджеты", "Проекты", "Аналитика"]
            delegate: Basic.Button {
                id: nav
                required property int index
                required property string modelData
                readonly property bool available: index < 2
                readonly property bool selected: available && sidebar.currentPage === index
                width: navigation.width; height: sidebar.shortWindow ? 44 : 48
                padding: 0; hoverEnabled: available
                enabled: available
                Accessible.name: modelData + (available ? "" : ", в разработке")
                contentItem: Item {
                    EditorialText {
                        width: sidebar.rail ? parent.width : 24; height: parent.height
                        text: (nav.index + 1).toString().padStart(2, "0")
                        font.family: DesktopTheme.mono; font.pixelSize: sidebar.rail ? 14 : 12
                        horizontalAlignment: sidebar.rail ? Text.AlignHCenter : Text.AlignLeft
                        color: nav.selected ? DesktopTheme.accent : DesktopTheme.muted
                    }
                    EditorialText {
                        x: 32; width: parent.width - 32; height: parent.height
                        visible: !sidebar.rail
                        text: nav.modelData
                        font.bold: nav.selected
                        color: nav.available ? (nav.hovered ? DesktopTheme.accent : DesktopTheme.ink) : DesktopTheme.muted
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: nav.available ? 0 : -8
                    }
                    EditorialText {
                        visible: !sidebar.rail && !nav.available
                        x: 32; y: 27; width: parent.width - 32; height: 16
                        text: "В разработке"; font.pixelSize: 10; color: DesktopTheme.muted
                    }
                }
                background: Item {
                    Rectangle { visible: nav.selected; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: DesktopTheme.ink }
                }
                onClicked: sidebar.pageRequested(index)
            }
        }
    }
    Column {
        x: sidebar.pad; width: parent.width - sidebar.pad * 2
        anchors.bottom: parent.bottom; anchors.bottomMargin: sidebar.topPad
        spacing: 16
        Rectangle {
            visible: !sidebar.rail && !sidebar.shortWindow && sidebar.height >= 860
            width: parent.width; height: 128
            color: "transparent"; border.color: DesktopTheme.ink
            EditorialText {
                x: 16; y: 16; width: parent.width - 32; height: 40
                text: "Keep count."; font.family: "Gelasio"; font.italic: true; font.pixelSize: 27
                fontSizeMode: Text.Fit; minimumPixelSize: 18
            }
            EditorialText {
                x: 16; y: 64; width: parent.width - 32; height: 48
                text: "Для тех, кто уважает свои деньги"
                font.family: DesktopTheme.mono; font.pixelSize: 12
                wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
        }
        Basic.Button {
            id: settings
            width: parent.width; height: 40; padding: 0
            hoverEnabled: true
            contentItem: Item {
                EditorialText {
                    x: sidebar.rail ? (parent.width - width) / 2 : 0
                    width: 20; height: parent.height
                    text: "⚙"; font.pixelSize: 14; color: DesktopTheme.muted
                }
                EditorialText {
                    x: 32; width: parent.width - 32; height: parent.height
                    visible: !sidebar.rail; text: "Настройки"; font.pixelSize: 14
                    font.bold: sidebar.currentPage === 2
                    color: settings.hovered ? DesktopTheme.accent : DesktopTheme.ink
                }
            }
            background: Item {
                Rectangle { visible: sidebar.currentPage === 2; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: DesktopTheme.ink }
            }
            onClicked: sidebar.pageRequested(2)
        }
        Item {
            width: parent.width; height: 48; visible: !sidebar.rail
            Rectangle { width: parent.width; height: 1; color: DesktopTheme.ink }
            EditorialText { height: parent.height; text: "VEXA"; font.family: DesktopTheme.mono; font.pixelSize: 12 }
            EditorialText { anchors.right: parent.right; height: parent.height; text: "© 2026"; font.family: DesktopTheme.mono; font.pixelSize: 12 }
        }
    }
}
