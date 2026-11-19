pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Basic.ItemDelegate {
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
    property int accountType: 0
    property string openingInput: ""
    property string limitInput: ""
    property bool includeDebtInTotal: true
    signal historyRequested(string recordId)
    signal removeRequested(string recordId, string description)
    signal editRequested(var data)

    padding: 0
    topPadding: 10
    bottomPadding: 10
    implicitHeight: Math.max(54, implicitContentHeight + topPadding + bottomPadding)
    Accessible.name: nameText + ", " + typeText + ", " + primaryLabel + " " + primaryText

    contentItem: ColumnLayout {
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1.25
                spacing: 2

                MobileEditorialText {
                    Layout.fillWidth: true
                    text: card.nameText
                    font.bold: true
                    font.pixelSize: 16
                }

                MobileEditorialText {
                    Layout.fillWidth: true
                    text: card.typeText + " · " + card.currencyCode
                    font.pixelSize: 12
                    color: MobileTheme.muted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 2

                MobileEditorialText {
                    Layout.fillWidth: true
                    text: card.primaryText
                    font.family: MobileTheme.serif
                    font.pixelSize: 23
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 13
                    horizontalAlignment: Text.AlignRight
                }

                MobileEditorialText {
                    Layout.fillWidth: true
                    visible: card.credit
                    text: card.primaryLabel
                    font.family: MobileTheme.mono
                    font.pixelSize: 11
                    color: MobileTheme.muted
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: card.credit
            text: "Лимит: " + card.limitText
            font.pixelSize: 12
            color: MobileTheme.muted
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: card.credit
            text: "Долг: " + card.debtText
            font.pixelSize: 12
            color: MobileTheme.historyExpense
        }
    }

    background: Rectangle {
        color: card.down ? MobileTheme.sidebar : "transparent"
        border.width: card.visualFocus ? 1 : 0
        border.color: MobileTheme.accent

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: MobileTheme.line
        }
    }

    onClicked: accountMenu.open()
    onPressAndHold: accountMenu.open()

    MobileContextActionMenu {
        id: accountMenu

        historyEnabled: true
        onHistoryRequested: card.historyRequested(card.recordId)
        onEditRequested: card.editRequested({
            id: card.recordId,
            name: card.nameText,
            type: card.accountType,
            currencyCode: card.currencyCode,
            openingInput: card.openingInput,
            limitInput: card.limitInput,
            includeDebtInTotal: card.includeDebtInTotal
        })
        onRemoveRequested: card.removeRequested(card.recordId, card.nameText)
    }
}
