
import QtQuick
import UI

Item {
    id: summary

    required property string totalText
    required property string accountsCaption

    property bool narrow: false
    property bool small: false
    property bool medium: false
    property bool compact: false

    implicitHeight: narrow ? 288 : compact ? 144 : 160

    component Mono: EditorialText {
        font.family: DesktopTheme.mono
        font.pixelSize: 12
        color: DesktopTheme.muted
    }

    component Serif: EditorialText {
        font.family: DesktopTheme.serif
        font.pixelSize: 36
        font.letterSpacing: -0.5
    }

    Rectangle {
        width: parent.width
        height: 1
        color: DesktopTheme.ink
    }

    Rectangle {
        y: parent.height - 1
        width: parent.width
        height: 1
        color: DesktopTheme.ink
    }

    Repeater {
        model: [
            "ВСЕ АКТИВЫ",
            "ФИАТ",
            "КРИПТО",
            "ИНВЕСТИЦИИ"
        ]

        delegate: Rectangle {
            id: tile

            required property int index
            required property string modelData

            readonly property bool dark: index === 0
            readonly property bool unavailable: index >= 2

            readonly property int cellPad:
                summary.small ? 16 :
                summary.medium ? 20 : 24

            x: summary.narrow
                ? (index % 2) * summary.width / 2
                : index === 0
                    ? 0
                    : summary.width * (3 + (index - 1) * 2) / 9

            y: summary.narrow
                ? Math.floor(index / 2) * 144
                : 0

            width: summary.narrow
                ? summary.width / 2
                : summary.width * (index === 0 ? 3 : 2) / 9

            height: summary.narrow ? 144 : summary.height

            color: dark ? DesktopTheme.ink : "transparent"

            Rectangle {
                visible: !tile.dark
                width: 1
                height: parent.height
                color: DesktopTheme.ink
            }

            Mono {
                visible: tile.unavailable
                anchors.right: parent.right
                anchors.rightMargin: 12

                y: summary.compact ? 16 : 24

                text: "↗"
                font.pixelSize: 18
            }

            Mono {
                x: tile.cellPad
                y: summary.compact ? 16 : 24

                width: parent.width - x - 8
                height: 24

                text: "0" + (tile.index + 1) +
                      " / " + tile.modelData

                font.letterSpacing: 0.5

                color: tile.dark
                    ? DesktopTheme.line
                    : DesktopTheme.muted
            }

            Serif {
                id: tileValue

                x: tile.cellPad
                y: (summary.compact ? 16 : 24) + 32

                width: parent.width - x - 12
                height: 56

                text: tile.unavailable
                    ? "—"
                    : summary.totalText

                font.pixelSize:
                    tile.dark
                    ? (summary.small ? 30 :
                       summary.medium ? 36 : 44)
                    : (summary.small ? 26 :
                       summary.medium ? 30 : 36)

                fontSizeMode: Text.Fit
                minimumPixelSize: 18

                color: tile.dark
                    ? DesktopTheme.sidebar
                    : DesktopTheme.ink
            }

            Mono {
                x: tile.cellPad
                y: tileValue.y + 64

                width: parent.width - x - 8
                height: 24

                text: tile.unavailable
                    ? "В разработке"
                    : summary.accountsCaption

                color: tile.dark
                    ? DesktopTheme.line
                    : DesktopTheme.muted
            }
        }
    }
}
