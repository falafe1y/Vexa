import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Rectangle {
    id: card
    property string recordId: ""
    property string nameText: ""
    property string typeText: ""
    property string currencyCode: ""
    property string primaryLabel: ""
    property string primaryText: ""
    property bool credit: false
    property string debtText: ""
    property string limitText: ""
    property bool busy: false
    signal removeRequested(string recordId, string description)

    implicitHeight: 212
    color: DesktopTheme.sidebar
    border.color: DesktopTheme.line
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            EditorialText {
                Layout.fillWidth: true
                text: card.nameText
                font.bold: true
                font.pixelSize: 16
            }
            ActionButton {
                implicitWidth: 28
                implicitHeight: 28
                leftPadding: 0
                rightPadding: 0
                text: "×"
                outlined: false
                enabled: !card.busy
                Accessible.name: "Убрать счёт"
                ToolTip.visible: hovered
                ToolTip.text: "Убрать счёт"
                onClicked: card.removeRequested(card.recordId, card.nameText)
            }
        }
        EditorialText {
            Layout.fillWidth: true
            text: card.typeText
            color: DesktopTheme.muted
            font.pixelSize: 12
        }
        Item { Layout.fillHeight: true }
        EditorialText {
            text: card.primaryLabel
            color: DesktopTheme.muted
            font.family: DesktopTheme.mono
            font.pixelSize: 10
        }
        EditorialText {
            Layout.fillWidth: true
            text: card.primaryText
            font.family: DesktopTheme.serif
            font.pixelSize: 30
            fontSizeMode: Text.Fit
            minimumPixelSize: 17
        }
        EditorialText {
            Layout.fillWidth: true
            text: card.credit ? "Лимит: " + card.limitText : card.currencyCode
            color: DesktopTheme.muted
            font.pixelSize: 11
        }
        RowLayout {
            Layout.fillWidth: true
            visible: card.credit
            EditorialText {
                text: "Долг"
                color: DesktopTheme.muted
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            EditorialText {
                text: card.debtText
                font.pixelSize: 13
                color: DesktopTheme.accent
            }
        }
    }
}
