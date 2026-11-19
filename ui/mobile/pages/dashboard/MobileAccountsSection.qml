pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger
    signal historyRequested(string accountId)
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)

    spacing: 0

    MobilePageHeading {
        Layout.fillWidth: true
        Layout.topMargin: 13
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        documentStyle: true
        text: "Счета"
    }

    ListView {
        id: accountList

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        clip: true
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        model: page.ledger.accountsModel

        Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

        delegate: MobileAccountCard {
            required property var model

            width: ListView.view.width
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
            enabled: !page.ledger.commandPending
            onHistoryRequested: recordId => page.historyRequested(recordId)
            onRemoveRequested: (recordId, description) => page.removeRequested(recordId, description)
            onEditRequested: data => page.editRequested(data)
        }

        MobileEditorialText {
            anchors.top: parent.top
            anchors.topMargin: 12
            width: parent.width
            visible: page.ledger.ready && accountList.count === 0
            text: "Счетов пока нет"
            color: MobileTheme.muted
        }
    }
}
