pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Flickable {
    id: page

    required property var ledger
    required property var updates
    required property bool landscape

    readonly property int pagePadding: width < 520 ? 16 : width <= 950 ? 24 : 32

    clip: true
    contentWidth: width
    contentHeight: settings.implicitHeight + 18 + pagePadding
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds

    Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

    ColumnLayout {
        id: settings

        x: page.pagePadding
        y: 18
        width: page.width - 2 * x
        spacing: 14

        TabletPageHeader {
            Layout.fillWidth: true
            title: "Настройки."
            landscape: page.landscape
            actions: [
                MobileBaseCurrencySelector {
                    Layout.preferredWidth: 90
                    Layout.maximumWidth: 96
                    visible: page.landscape
                    label: "ВАЛЮТА"
                    ledger: page.ledger
                }
            ]
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 720
            visible: !page.landscape
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 4

                MobileEditorialText {
                    Layout.fillWidth: true
                    text: "Базовая валюта"
                    font.bold: true
                    font.pixelSize: 16
                }

                MobileEditorialText {
                    Layout.fillWidth: true
                    text: "В ней показывается общая стоимость активов."
                    wrapMode: Text.Wrap
                    color: MobileTheme.muted
                }
            }

            MobileBaseCurrencySelector {
                Layout.preferredWidth: 94
                Layout.maximumWidth: 110
                label: "БАЗОВАЯ ВАЛЮТА"
                ledger: page.ledger
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 720
            implicitHeight: 1
            visible: !page.landscape
            color: MobileTheme.line
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: !page.landscape
            text: "Версия Vexa " + page.updates.currentVersion
            font.family: MobileTheme.mono
            font.pixelSize: 12
            color: MobileTheme.muted
        }

        MobileActionButton {
            visible: page.updates.updateAvailable
            text: "ПОЛУЧИТЬ ОБНОВЛЕНИЕ"
            onClicked: page.updates.openReleasePage()
        }
    }
}
