pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: summary

    required property string totalText
    required property string accountsCaption

    spacing: 8

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: total.implicitHeight + 30
        radius: 8
        color: MobileTheme.ink

        ColumnLayout {
            id: total

            anchors.fill: parent
            anchors.margins: 15
            spacing: 4

            MobileEditorialText {
                Layout.fillWidth: true
                text: "ВСЕ АКТИВЫ"
                font.family: MobileTheme.mono
                font.pixelSize: 11
                color: MobileTheme.line
            }

            MobileEditorialText {
                Layout.fillWidth: true
                text: summary.totalText
                font.family: MobileTheme.serif
                font.pixelSize: 36
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 17
                color: MobileTheme.sidebar
            }

            MobileEditorialText {
                Layout.fillWidth: true
                text: summary.accountsCaption
                font.pixelSize: 13
                color: MobileTheme.line
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: fiat.implicitHeight + 22
        radius: 6
        color: MobileTheme.sidebar
        border.width: 1
        border.color: MobileTheme.line

        RowLayout {
            id: fiat

            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            MobileEditorialText {
                text: "ФИАТ"
                font.family: MobileTheme.mono
                font.pixelSize: 11
            }

            MobileEditorialText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: summary.totalText
                font.family: MobileTheme.serif
                font.pixelSize: 21
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 14
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: ["Крипто", "Инвестиции"]

            delegate: Rectangle {
                id: tile

                required property string modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 56
                radius: 6
                color: MobileTheme.soft

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 2 * x
                    spacing: 2

                    MobileEditorialText {
                        width: parent.width
                        text: tile.modelData
                        font.bold: true
                    }

                    MobileEditorialText {
                        width: parent.width
                        text: "В разработке"
                        font.pixelSize: 11
                        color: MobileTheme.muted
                    }
                }
            }
        }
    }
}
