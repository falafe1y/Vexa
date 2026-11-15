pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: summary

    required property bool landscape
    required property string totalText
    required property string accountsCaption

    readonly property int gap: 8
    readonly property int portraitTotalHeight: 140
    readonly property int portraitTileHeight: 86
    readonly property real portraitTileWidth: (width - 2 * gap) / 3

    implicitHeight: landscape ? (width < 720 ? 116 : 144)
        : portraitTotalHeight + gap + portraitTileHeight

    component AssetTile: Rectangle {
        id: tile

        required property string label
        required property int landscapeIndex
        property int portraitIndex: 0
        property string value: ""
        property string note: ""
        property bool total: false
        property bool unavailable: false

        readonly property int inset: summary.landscape
            ? Math.min(24, Math.max(10, Math.round(summary.width * 0.02)))
            : total ? 22 : width < 130 ? 8 : 14

        x: tile.total ? 0 : summary.landscape
            ? summary.width * (1 + 2 * landscapeIndex) / 9
            : portraitIndex * (summary.portraitTileWidth + summary.gap)
        y: summary.landscape || tile.total ? 0 : summary.portraitTotalHeight + summary.gap
        width: summary.landscape
            ? summary.width * (total ? 3 : 2) / 9
            : total ? summary.width : summary.portraitTileWidth
        height: summary.landscape ? summary.height
            : total ? summary.portraitTotalHeight : summary.portraitTileHeight
        radius: summary.landscape ? 0 : total ? 8 : 6
        color: total ? MobileTheme.ink
            : summary.landscape ? "transparent"
            : unavailable ? MobileTheme.soft : MobileTheme.sidebar
        border.width: summary.landscape || total || unavailable ? 0 : 1
        border.color: MobileTheme.line

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: tile.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            MobileEditorialText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: summary.landscape ? "0" + (tile.landscapeIndex + 1) + " / " + tile.label : tile.label
                font.family: MobileTheme.mono
                font.pixelSize: 12
                color: tile.total ? MobileTheme.line : MobileTheme.muted
            }

            MobileEditorialText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: summary.landscape || !tile.unavailable
                text: tile.unavailable ? "—" : tile.value
                font.family: MobileTheme.serif
                font.pixelSize: summary.landscape
                    ? (tile.total ? Math.round(Math.min(44, tile.width * 0.17)) : 30)
                    : (tile.total ? 48 : 25)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 13
                color: tile.total ? MobileTheme.sidebar : MobileTheme.ink
            }

            MobileEditorialText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: tile.note
                font.pixelSize: 12
                color: tile.total ? MobileTheme.line : MobileTheme.muted
                visible: text.length > 0
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: summary.landscape
            height: 1
            color: MobileTheme.ink
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: summary.landscape && !tile.total
            width: 1
            color: MobileTheme.ink
        }
    }

    AssetTile {
        total: true
        landscapeIndex: 0
        label: "ВСЕ АКТИВЫ"
        value: summary.totalText
        note: summary.accountsCaption
    }

    AssetTile {
        landscapeIndex: 1
        portraitIndex: 0
        label: "ФИАТ"
        value: summary.totalText
        note: summary.landscape ? summary.accountsCaption : "В базовой валюте"
    }

    AssetTile {
        landscapeIndex: 3
        portraitIndex: 1
        label: "ИНВЕСТИЦИИ"
        unavailable: true
        note: "В разработке"
    }

    AssetTile {
        landscapeIndex: 2
        portraitIndex: 2
        label: "КРИПТО"
        unavailable: true
        note: "В разработке"
    }
}
