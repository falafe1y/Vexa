import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Flickable {
    id: page

    required property var ledger
    signal backRequested()
    required property var updates

    clip: true
    contentWidth: width
    contentHeight: settings.implicitHeight + 2 * MobileTheme.pagePadding
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds

    Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

    ColumnLayout {
        id: settings

        x: MobileTheme.pagePadding
        y: 14
        width: page.width - 2 * x
        spacing: 16

        MobileActionButton {
            flat: true
            text: "‹ Ещё"
            Accessible.name: "Вернуться в раздел «Ещё»"
            onClicked: page.backRequested()
        }

        MobilePageHeading {
            Layout.fillWidth: true
            documentStyle: true
            text: "Настройки"
        }

        MobileBaseCurrencySelector {
            Layout.fillWidth: true
            label: "БАЗОВАЯ ВАЛЮТА"
            ledger: page.ledger
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: MobileTheme.line
        }

        MobileEditorialText {
            Layout.fillWidth: true
            text: "Версия Vexa " + page.updates.currentVersion
            font.family: MobileTheme.mono
            font.pixelSize: 12
            color: MobileTheme.muted
        }

        MobileActionButton {
            Layout.fillWidth: true
            visible: page.updates.updateAvailable
            text: "ПОЛУЧИТЬ ОБНОВЛЕНИЕ"
            onClicked: page.updates.openReleasePage()
        }
    }
}
