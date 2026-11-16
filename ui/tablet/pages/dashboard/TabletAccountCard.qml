pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    required property var account
    required property int position
    required property bool landscape
    required property bool busy
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)

    readonly property int inset: landscape ? 0 : 12

    color: landscape ? "transparent" : MobileTheme.sidebar
    border.width: landscape ? 0 : 1
    border.color: MobileTheme.line
    radius: landscape ? 0 : 6

    MobileEditorialText {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: card.landscape
        width: 28
        text: (card.position + 1).toString().padStart(2, "0")
        font.family: MobileTheme.mono
        font.pixelSize: 12
        color: MobileTheme.muted
    }

    ColumnLayout {
        id: details

        x: card.landscape ? 28 : card.inset
        y: card.landscape ? (card.height - height) / 2 : 14
        width: card.landscape
            ? Math.max(0, amounts.x - x - 8)
            : Math.max(0, actions.x - x - 4)
        spacing: 3

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: card.account.name
            font.bold: true
            font.pixelSize: 16
        }

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: card.account.typeText + " · " + card.account.currencyCode
            font.pixelSize: 12
            color: MobileTheme.muted
        }
    }

    ColumnLayout {
        id: amounts

        x: card.landscape ? actions.x - width : card.inset
        y: card.landscape ? (card.height - height) / 2 : card.height - height - card.inset
        width: card.landscape ? Math.min(178, card.width * 0.44) : card.width - 2 * card.inset
        spacing: 4

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: card.account.primaryText
            font.family: MobileTheme.serif
            font.pixelSize: card.landscape ? 21 : 24
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 13
            horizontalAlignment: card.landscape ? Text.AlignRight : Text.AlignLeft
        }

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: card.account.isCreditCard
            text: "Долг " + card.account.debtText
            font.pixelSize: 11
            color: MobileTheme.muted
            horizontalAlignment: card.landscape ? Text.AlignRight : Text.AlignLeft
        }
    }

    TabletRowActions {
        id: actions

        anchors.right: parent.right
        anchors.rightMargin: card.landscape ? 0 : 4
        y: card.landscape ? (card.height - height) / 2 : 0
        enabled: !card.busy
        label: "Действия со счётом " + card.account.name
        onEditRequested: card.editRequested({
            id: card.account.id,
            name: card.account.name,
            type: card.account.type,
            currencyCode: card.account.currencyCode,
            openingInput: card.account.openingInput,
            limitInput: card.account.limitInput,
            includeDebtInTotal: card.account.includeDebtInTotal
        })
        onRemoveRequested: card.removeRequested(card.account.id, card.account.name)
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        visible: card.landscape
        color: MobileTheme.line
    }
}
