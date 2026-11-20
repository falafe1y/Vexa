pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger
    readonly property bool compact: height < 520

    signal accountsRequested()
    signal assetRequested(string name)
    signal operationActionsRequested(var data)

    spacing: 0

    MobileAssetSummary {
        Layout.fillWidth: true
        Layout.topMargin: page.compact ? 8 : 21
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        totalText: page.ledger.totalBalanceText
        compact: page.compact
        onAccountsRequested: page.accountsRequested()
        onAssetRequested: name => page.assetRequested(name)
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        Layout.topMargin: page.compact ? 8 : 18
        Layout.bottomMargin: 10

        MobileEditorialText {
            Layout.fillWidth: true
            text: "Счета"
            font.family: MobileTheme.serif
            font.pixelSize: 19
            Accessible.role: Accessible.Heading
        }

        Basic.Button {
            id: allHistory

            readonly property bool selected: page.ledger.historyAccountId.length === 0

            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 4
            bottomPadding: 4
            text: "Вся история"
            Accessible.name: "История по всем счетам"
            Accessible.selected: selected
            onClicked: page.ledger.historyAccountId = ""

            contentItem: MobileEditorialText {
                text: allHistory.text
                font.pixelSize: 12
                color: allHistory.selected ? MobileTheme.accent : MobileTheme.ink
            }

            background: Rectangle {
                color: allHistory.down ? MobileTheme.soft : "transparent"
                border.width: allHistory.visualFocus ? 1 : 0
                border.color: MobileTheme.accent

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    visible: allHistory.selected
                    color: MobileTheme.accent
                }
            }
        }
    }

    MobileAccountStrip {
        Layout.fillWidth: true
        ledger: page.ledger
        compact: page.compact
        showAllAccounts: false
        visible: page.ledger.accountsModel.count > 0
    }

    MobileEditorialText {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        Layout.bottomMargin: 13
        visible: page.ledger.ready && page.ledger.accountsModel.count === 0
        text: "Счетов пока нет"
        color: MobileTheme.muted
    }

    MobileHistorySection {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ledger: page.ledger
        onOperationActionsRequested: data => page.operationActionsRequested(data)
    }
}
