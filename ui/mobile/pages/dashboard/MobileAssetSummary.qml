pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: summary

    required property string totalText
    property bool compact: false

    signal accountsRequested()
    signal assetRequested(string name)

    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: summary.compact ? 90 : Math.max(117, Math.min(147, width * 0.34))
        color: MobileTheme.ink

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 19
            anchors.rightMargin: 19
            spacing: 0

            Item { Layout.fillHeight: true }

            MobileEditorialText {
                Layout.fillWidth: true
                text: "ОБЩИЙ ИТОГ"
                font.family: MobileTheme.mono
                font.pixelSize: 13
                color: MobileTheme.line
            }

            MobileEditorialText {
                Layout.fillWidth: true
                Layout.topMargin: 6
                text: summary.totalText
                font.family: MobileTheme.serif
                font.pixelSize: Math.max(34, Math.min(52, width * 0.12))
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 17
                color: MobileTheme.sidebar
            }

            Item { Layout.fillHeight: true }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: summary.compact ? 58 : 69
        color: MobileTheme.ink

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            anchors.bottomMargin: 1
            spacing: 1

            Repeater {
                model: ["Фиат", "Криптовалюта", "Инвестиции"]

                delegate: Basic.Button {
                    id: asset

                    required property int index
                    required property string modelData
                    readonly property bool fiat: index === 0
                    readonly property string detail: fiat ? summary.totalText : "В разработке"

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    padding: Math.max(6, Math.min(12, width * 0.08))
                    text: modelData
                    Accessible.name: text + ", " + detail

                    contentItem: Item {
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            spacing: 7

                            MobileEditorialText {
                                width: parent.width
                                text: asset.text.toUpperCase()
                                font.family: MobileTheme.mono
                                font.pixelSize: 12
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 9
                            }

                            MobileEditorialText {
                                width: parent.width
                                text: asset.detail
                                font.family: asset.fiat ? MobileTheme.serif : MobileTheme.sans
                                font.pixelSize: asset.fiat ? 16 : 12
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 9
                                color: asset.fiat ? MobileTheme.ink : MobileTheme.muted
                            }
                        }
                    }

                    background: Rectangle {
                        color: asset.down ? MobileTheme.soft : MobileTheme.paper
                        border.width: asset.visualFocus ? 1 : 0
                        border.color: MobileTheme.accent
                    }

                    onClicked: {
                        if (fiat)
                            summary.accountsRequested()
                        else
                            summary.assetRequested(text)
                    }
                }
            }
        }
    }
}
