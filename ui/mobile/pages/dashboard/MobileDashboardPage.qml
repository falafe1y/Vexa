pragma ComponentBehavior: Bound
import QtQuick
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
        Layout.topMargin: page.compact ? 8 : 13
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        totalText: page.ledger.totalBalanceText
        compact: page.compact
        onAccountsRequested: page.accountsRequested()
        onAssetRequested: name => page.assetRequested(name)
    }

    MobileAccountStrip {
        Layout.fillWidth: true
        Layout.topMargin: page.compact ? 8 : 14
        Layout.bottomMargin: 6
        ledger: page.ledger
        compact: page.compact
    }

    MobileHistorySection {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ledger: page.ledger
        onOperationActionsRequested: data => page.operationActionsRequested(data)
    }
}
