pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger

    signal backRequested()
    signal operationActionsRequested(var data)

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        Layout.topMargin: 8
        spacing: 8

        MobileActionButton {
            flat: true
            implicitWidth: 44
            padding: 0
            text: "‹"
            font.family: MobileTheme.serif
            font.pixelSize: 28
            font.bold: false
            Accessible.name: "Вернуться к обзору"
            onClicked: page.backRequested()
        }

        MobileEditorialText {
            Layout.fillWidth: true
            text: page.ledger.historyCategoryName || "История операций"
            font.family: MobileTheme.serif
            font.pixelSize: 24
            Accessible.role: Accessible.Heading
        }
    }

    MobileAccountStrip {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 12
        ledger: page.ledger
        compact: page.height < 520
    }

    MobileHistorySection {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ledger: page.ledger
        showHeading: false
        showFilters: true
        onOperationActionsRequested: data => page.operationActionsRequested(data)
    }
}
