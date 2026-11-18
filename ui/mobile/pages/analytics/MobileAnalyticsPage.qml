pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Flickable {
    id: page

    required property var ledger
    signal backRequested()

    clip: true
    contentWidth: width
    contentHeight: content.implicitHeight + 14 + MobileTheme.pagePadding
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: content

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
            text: "Аналитика"
        }

        ExpenseBreakdown {
            Layout.fillWidth: true
            ledger: page.ledger
            theme: MobileTheme
        }
    }
}
