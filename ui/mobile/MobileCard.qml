import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: card
    property bool hard: false
    property color fill: MobileTheme.panel
    property int cardPadding: 16
    property int gap: 12
    default property alias content: column.data
    padding: cardPadding
    contentItem: ColumnLayout {
        id: column
        spacing: card.gap
    }
    background: Rectangle {
        color: card.fill
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: MobileTheme.line
        }
    }
}
