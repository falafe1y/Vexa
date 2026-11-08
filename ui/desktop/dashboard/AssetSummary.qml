import QtQuick
import QtQuick.Layouts
import UI

RowLayout {
    id: summary
    required property string totalText
    required property string accountsCaption
    spacing: 0
    implicitHeight: 154

    AssetTile {
        Layout.fillWidth: true
        Layout.preferredWidth: 3
        Layout.minimumWidth: 180
        Layout.fillHeight: true
        caption: "01 / ВСЕ АКТИВЫ"
        value: summary.totalText
        note: "Чистый капитал"
        dark: true
    }
    AssetTile {
        Layout.fillWidth: true
        Layout.preferredWidth: 2
        Layout.minimumWidth: 125
        Layout.fillHeight: true
        caption: "02 / ФИАТ"
        value: summary.totalText
        note: summary.accountsCaption
    }
    AssetTile {
        Layout.fillWidth: true
        Layout.preferredWidth: 2
        Layout.minimumWidth: 125
        Layout.fillHeight: true
        caption: "03 / КРИПТО"
        value: "—"
        note: "В разработке"
        enabled: false
        opacity: 0.45
    }
    AssetTile {
        Layout.fillWidth: true
        Layout.preferredWidth: 2
        Layout.minimumWidth: 125
        Layout.fillHeight: true
        caption: "04 / ИНВЕСТИЦИИ"
        value: "—"
        note: "В разработке"
        enabled: false
        opacity: 0.45
    }

    component AssetTile: Rectangle {
        id: tile
        property string caption: ""
        property string value: ""
        property string note: ""
        property bool dark: false
        color: dark ? DesktopTheme.ink : "transparent"
        border.width: 1
        border.color: DesktopTheme.ink
        Accessible.role: Accessible.StaticText
        Accessible.name: caption + ". " + value + ". " + note

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            EditorialText {
                Layout.fillWidth: true
                text: tile.caption
                font.family: DesktopTheme.mono
                font.pixelSize: 10
                color: tile.dark ? DesktopTheme.line : DesktopTheme.muted
            }
            EditorialText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: tile.value
                font.family: DesktopTheme.serif
                font.pixelSize: 34
                fontSizeMode: Text.Fit
                minimumPixelSize: 17
                color: tile.dark ? DesktopTheme.sidebar : DesktopTheme.ink
            }
            EditorialText {
                Layout.fillWidth: true
                text: tile.note
                font.pixelSize: 11
                color: tile.dark ? DesktopTheme.line : DesktopTheme.muted
            }
        }
    }
}
