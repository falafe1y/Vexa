import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var ledger
    property string label: "ВАЛЮТА"

    spacing: 4

    MobileEditorialText {
        Layout.fillWidth: true
        text: root.label
        font.family: MobileTheme.mono
        font.pixelSize: 11
        color: MobileTheme.muted
    }

    MobileSelectField {
        Layout.fillWidth: true
        Layout.preferredWidth: 86
        enabled: root.ledger.ready && !root.ledger.commandPending
        Accessible.name: root.label
        model: root.ledger.currencyCodes
        currentIndex: root.ledger.baseCurrencyIndex
        onActivated: index => root.ledger.setBaseCurrencyCode(root.ledger.currencyCodes[index])
    }
}
