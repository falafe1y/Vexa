import QtQuick
import QtQuick.Layouts

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
    property int accountType: 0
    property string openingInput: ""
    property string limitInput: ""
    signal removeRequested(string recordId, string description)
    signal editRequested(var data)

    implicitHeight: details.implicitHeight + 20
    height: implicitHeight
    radius: 6
    color: MobileTheme.sidebar
    border.color: MobileTheme.line
    border.width: 1

    ColumnLayout {
        id: details

        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
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

            MobileActionButton {
                flat: true
                text: "⋯"
                font.pixelSize: 21
                enabled: !card.busy
                Accessible.name: "Действия со счётом " + card.nameText
                onClicked: accountMenu.open()

                MobileContextActionMenu {
                    id: accountMenu

                    editEnabled: !card.busy
                    removeEnabled: !card.busy
                    onEditRequested: card.editRequested({
                        id: card.recordId,
                        name: card.nameText,
                        type: card.accountType,
                        currencyCode: card.currencyCode,
                        openingInput: card.openingInput,
                        limitInput: card.limitInput
                    })
                    onRemoveRequested: card.removeRequested(card.recordId, card.nameText)
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true

            MobileEditorialText {
                text: card.primaryLabel
                font.family: MobileTheme.mono
                font.pixelSize: 11
                color: MobileTheme.muted
            }

            MobileEditorialText {
                Layout.fillWidth: true
                text: card.primaryText
                font.family: MobileTheme.serif
                font.pixelSize: 24
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 13
                horizontalAlignment: Text.AlignRight
            }
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: card.credit
            text: "Лимит: " + card.limitText
            font.pixelSize: 13
            color: MobileTheme.muted
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: card.credit
            text: "Долг: " + card.debtText
            font.pixelSize: 13
            color: MobileTheme.accent
        }
    }
}
