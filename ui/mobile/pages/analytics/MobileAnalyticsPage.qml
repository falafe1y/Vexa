pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Flickable {
    id: page

    required property var ledger

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

        MobilePageHeading {
            Layout.fillWidth: true
            text: "Аналитика."
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: MobileTheme.ink
        }

        ExpenseBreakdown {
            Layout.fillWidth: true
            ledger: page.ledger
            theme: MobileTheme
        }
    }
}
