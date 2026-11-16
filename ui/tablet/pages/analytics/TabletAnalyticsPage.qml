pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Flickable {
    id: page

    required property var ledger
    required property bool landscape

    readonly property int pagePadding: width < 520 ? 16 : width <= 950 ? 24 : 32

    clip: true
    contentWidth: width
    contentHeight: content.implicitHeight + 18 + pagePadding
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: content

        x: page.pagePadding
        y: 18
        width: page.width - 2 * x
        spacing: 14

        TabletPageHeader {
            Layout.fillWidth: true
            title: "Аналитика."
            landscape: page.landscape
        }

        ExpenseBreakdown {
            Layout.fillWidth: true
            ledger: page.ledger
            theme: MobileTheme
        }
    }
}
