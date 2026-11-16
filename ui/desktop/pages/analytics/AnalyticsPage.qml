pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import UI

Flickable {
    id: page

    required property var ledger
    readonly property int pagePadding: width <= 650 ? 20 : width <= 950 ? 24 : width <= 1300 ? 32 : 48

    clip: true
    contentWidth: width
    contentHeight: content.implicitHeight + 24 + pagePadding
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: content

        x: page.pagePadding
        y: 24
        width: page.width - 2 * x
        spacing: 20

        EditorialText {
            Layout.fillWidth: true
            text: "Аналитика."
            font.family: DesktopTheme.serif
            font.italic: true
            font.letterSpacing: -2
            font.pixelSize: page.width <= 950 ? 56 : 72
            Accessible.role: Accessible.Heading
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: DesktopTheme.ink
        }

        ExpenseBreakdown {
            Layout.fillWidth: true
            ledger: page.ledger
            theme: DesktopTheme
        }
    }
}
