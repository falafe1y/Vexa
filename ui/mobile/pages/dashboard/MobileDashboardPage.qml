pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger

    signal accountsRequested()
    signal assetRequested(string name)
    signal operationActionsRequested(var data)

    spacing: 17

    MobileAssetSummary {
        Layout.fillWidth: true
        Layout.topMargin: 13
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        totalText: page.ledger.totalBalanceText
        compact: page.height < 416

        onAccountsRequested: page.accountsRequested()
        onAssetRequested: name => page.assetRequested(name)
    }

    ListView {
        id: history

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        clip: true
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        model: page.ledger.historyModel

        Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

        section.property: "dateText"
        section.delegate: MobileEditorialText {
            required property string section

            width: history.width
            topPadding: 12
            bottomPadding: 3
            text: section.charAt(0) === "0" ? section.slice(1, 2) : section.slice(0, 2)
            font.family: MobileTheme.mono
            font.pixelSize: 15
            Accessible.role: Accessible.Heading
            Accessible.name: section
        }

        delegate: MobileHistoryRow {
            required property var model

            width: ListView.view.width
            recordId: model.id
            dateText: model.dateText
            accountId: model.accountId
            secondaryId: model.secondaryId
            amountInput: model.amountInput
            operationType: model.type
            accountText: model.accountText
            secondaryAccountText: model.secondaryAccountText
            categoryText: model.categoryText
            primaryAmountText: model.primaryAmountText
            secondaryAmountText: model.secondaryAmountText
            descriptionText: model.descriptionText
            enabled: !page.ledger.commandPending
            onActionsRequested: data => page.operationActionsRequested(data)
        }

        footer: ColumnLayout {
            width: history.width
            spacing: 8

            MobileEditorialText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: page.ledger.historyCaption
                color: MobileTheme.muted
            }

            MobileActionButton {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                visible: page.ledger.historyHasMore || page.ledger.historyLoading && history.count > 0
                text: page.ledger.historyLoading ? "Загрузка…" : "Показать ещё"
                cornerRadius: 0
                enabled: page.ledger.historyHasMore && !page.ledger.historyLoading
                onClicked: page.ledger.loadMoreHistory()
            }
        }
    }
}
