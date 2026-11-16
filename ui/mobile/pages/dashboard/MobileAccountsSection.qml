pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: section

    required property var ledger
    signal createRequested()
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MobileEditorialText {
            Layout.fillWidth: true
            text: "Счета"
            font.family: MobileTheme.serif
            font.pixelSize: 25
        }

        MobileActionButton {
            text: "+ СЧЁТ"
            Accessible.name: "Добавить счёт"
            enabled: section.ledger.ready && !section.ledger.commandPending
            onClicked: section.createRequested()
        }
    }

    MobileEditorialText {
        Layout.fillWidth: true
        visible: section.ledger.ready && accountList.count === 0
        text: "Счетов пока нет."
        color: MobileTheme.muted
    }

    ListView {
        id: accountList

        Layout.fillWidth: true
        Layout.preferredHeight: 150
        visible: count > 0
        clip: true
        interactive: count > 1
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        flickDeceleration: 3000
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 8
        model: section.ledger.accountsModel

        Basic.ScrollIndicator.horizontal: Basic.ScrollIndicator {}

        delegate: MobileAccountCard {
            required property var model

            width: ListView.view.width - (ListView.view.count > 1 ? 24 : 0)
            height: ListView.view.height
            accountType: model.type
            openingInput: model.openingInput
            limitInput: model.limitInput
            includeDebtInTotal: model.includeDebtInTotal
            recordId: model.id
            nameText: model.name
            typeText: model.typeText
            currencyCode: model.currencyCode
            primaryLabel: model.primaryLabel
            primaryText: model.primaryText
            credit: model.isCreditCard
            debtText: model.debtText
            limitText: model.creditLimitText
            busy: section.ledger.commandPending
            onRemoveRequested: (recordId, description) => section.removeRequested(recordId, description)
            onEditRequested: data => section.editRequested(data)
        }
    }
}
