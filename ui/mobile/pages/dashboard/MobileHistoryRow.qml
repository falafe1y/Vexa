pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: row

    property string recordId: ""
    property string dateText: ""
    property string accountId: ""
    property string secondaryId: ""
    property string amountInput: ""
    property string typeText: ""
    property int operationType: 0
    property string accountText: ""
    property string secondaryAccountText: ""
    property string categoryText: ""
    property string primaryAmountText: ""
    property string secondaryAmountText: ""
    property string descriptionText: ""
    property bool busy: false
    signal removeRequested(string recordId, string description)
    signal editRequested(var data)

    implicitHeight: details.implicitHeight + 12
    height: implicitHeight

    component Amount: MobileEditorialText {
        Layout.fillWidth: true
        Layout.preferredWidth: details.width * 0.48
        horizontalAlignment: Text.AlignRight
        font.family: MobileTheme.mono
        font.bold: true
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 11
    }

    ColumnLayout {
        id: details

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: MobileTheme.pagePadding
        anchors.rightMargin: MobileTheme.pagePadding
        y: 4
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MobileEditorialText {
                text: row.dateText
                font.family: MobileTheme.mono
                font.pixelSize: 12
                color: MobileTheme.muted
            }

            MobileEditorialText {
                Layout.fillWidth: true
                text: row.typeText
                font.pixelSize: 12
                color: MobileTheme.muted
            }

            MobileActionButton {
                flat: true
                text: "⋯"
                font.pixelSize: 21
                enabled: !row.busy
                Accessible.name: "Действия с операцией " + row.dateText
                onClicked: operationMenu.open()

                MobileContextActionMenu {
                    id: operationMenu

                    editEnabled: !row.busy
                    removeEnabled: !row.busy
                    onEditRequested: row.editRequested({
                        id: row.recordId,
                        type: row.operationType,
                        accountId: row.accountId,
                        secondaryId: row.secondaryId,
                        amountInput: row.amountInput,
                        dateText: row.dateText,
                        descriptionText: row.descriptionText
                    })
                    onRemoveRequested: row.removeRequested(row.recordId, row.descriptionText)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 4

            MobileEditorialText {
                Layout.fillWidth: true
                Layout.preferredWidth: details.width * 0.52
                text: row.accountText
                font.bold: true
            }

            Amount {
                text: row.primaryAmountText
                color: row.operationType === 0 ? MobileTheme.income : MobileTheme.accent
            }

            MobileEditorialText {
                Layout.fillWidth: true
                Layout.preferredWidth: details.width * 0.52
                text: row.secondaryAccountText
                visible: row.operationType === 2
                color: MobileTheme.muted
            }

            Amount {
                text: row.secondaryAmountText
                visible: row.operationType === 2
                color: MobileTheme.income
            }
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: row.operationType !== 2 && text.length > 0
            text: row.categoryText
            font.pixelSize: 13
            color: MobileTheme.muted
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: row.descriptionText
            font.pixelSize: 13
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: details.left
        anchors.right: details.right
        height: 1
        color: MobileTheme.line
    }
}
