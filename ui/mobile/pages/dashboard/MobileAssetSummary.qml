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

    MobileEditorialText {
        Layout.fillWidth: true
        text: "ОБЩИЙ ОСТАТОК"
        font.family: MobileTheme.mono
        font.pixelSize: 12
        font.letterSpacing: 0.54
        color: MobileTheme.muted
    }

    MobileEditorialText {
        Layout.fillWidth: true
        Layout.topMargin: summary.compact ? 4 : 7
        text: summary.totalText
        font.family: MobileTheme.serif
        font.pixelSize: summary.compact ? 32 : summary.width < 348 ? 38 : 44
        font.letterSpacing: -1.2
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 17
        Accessible.role: Accessible.StaticText
        Accessible.name: summary.totalText
    }

    Item {
        Layout.fillWidth: true
        Layout.topMargin: summary.compact ? 10 : 17
        implicitHeight: assetTabs.implicitHeight

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: MobileTheme.line
        }

        RowLayout {
            id: assetTabs

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: summary.width < 348 ? 13 : 18

            Repeater {
                model: ["Фиат", "Криптовалюта", "Инвестиции"]

                delegate: Basic.Button {
                    id: asset

                    required property int index
                    required property string modelData
                    readonly property bool fiat: index === 0

                    Layout.minimumWidth: 0
                    Layout.maximumWidth: implicitWidth
                    Layout.fillWidth: true
                    padding: 0
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 9
                    bottomPadding: 10
                    text: modelData
                    Accessible.name: fiat ? text : text + ", в разработке"
                    Accessible.selected: fiat

                    contentItem: MobileEditorialText {
                        text: asset.text
                        font.pixelSize: summary.width < 348 ? 13 : 14
                        color: asset.fiat ? MobileTheme.ink : MobileTheme.muted
                        elide: Text.ElideNone
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 10
                    }

                    background: Rectangle {
                        color: asset.down ? MobileTheme.soft : "transparent"
                        border.width: asset.visualFocus ? 1 : 0
                        border.color: MobileTheme.accent

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            visible: asset.fiat
                            color: MobileTheme.accent
                        }
                    }

                    onClicked: {
                        if (fiat)
                            summary.accountsRequested()
                        else
                            summary.assetRequested(text)
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
        }
    }
}
