pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: row

    required property bool landscape
    property var operation: null
    property bool busy: false
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)

    readonly property bool heading: operation === null
    readonly property bool transfer: operation?.type === 2
    readonly property bool showDescription: width > 800
    readonly property real cellWidth: Math.max(0, width - MobileTheme.touchSize)
    readonly property real dateWidth: Math.min(114, cellWidth * 0.16)
    readonly property real typeWidth: Math.min(108, cellWidth * 0.14)
    readonly property real accountWidth: cellWidth * (showDescription ? 0.21 : 0.30)
    readonly property real amountWidth: Math.min(140, cellWidth * 0.24)
    readonly property real categoryWidth: showDescription ? cellWidth * 0.17
        : cellWidth - dateWidth - typeWidth - accountWidth - amountWidth
    readonly property real descriptionWidth: cellWidth - dateWidth - typeWidth
        - accountWidth - categoryWidth - amountWidth
    readonly property string accountText: transfer
        ? operation.accountText + " " + operation.secondaryAccountText : operation?.accountText ?? ""
    readonly property string operationTitle: transfer ? operation.typeText
        : (operation?.categoryText || operation?.typeText || "")
    readonly property color amountColor: operation?.type === 0 ? MobileTheme.income : MobileTheme.accent

    implicitHeight: heading ? 40 : landscape ? 58 : Math.max(68, compactRow.implicitHeight + 14)
    height: implicitHeight

    component RegisterCell: MobileEditorialText {
        height: row.height
        leftPadding: 6
        rightPadding: 6
        font.family: row.heading ? MobileTheme.mono : MobileTheme.sans
        font.pixelSize: row.heading || row.width <= 800 ? 12 : 14
    }

    component AmountText: MobileEditorialText {
        font.family: MobileTheme.mono
        font.bold: true
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 11
        horizontalAlignment: Text.AlignRight
    }

    Rectangle {
        anchors.fill: parent
        visible: row.heading
        color: MobileTheme.soft
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: row.landscape

        RegisterCell {
            width: row.dateWidth
            text: row.heading ? "ДАТА" : row.operation?.dateText ?? ""
            font.family: MobileTheme.mono
        }

        RegisterCell {
            width: row.typeWidth
            text: row.heading ? "ТИП" : row.operation?.typeText ?? ""
            color: row.heading ? MobileTheme.ink : MobileTheme.muted
        }

        RegisterCell {
            width: row.accountWidth
            text: row.heading ? "СЧЁТ" : row.accountText
            elide: row.heading ? Text.ElideRight : Text.ElideNone
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }

        RegisterCell {
            width: row.categoryWidth
            text: row.heading ? "КАТЕГОРИЯ" : row.operation?.categoryText ?? ""
        }

        RegisterCell {
            width: row.descriptionWidth
            visible: row.showDescription
            text: row.heading ? "ОПИСАНИЕ" : row.operation?.descriptionText ?? ""
        }

        Item {
            width: row.amountWidth
            height: row.height

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                AmountText {
                    width: parent.width
                    text: row.heading ? "СУММА" : row.operation?.primaryAmountText ?? ""
                    font.pixelSize: row.heading ? 12 : 14
                    font.bold: !row.heading
                    color: row.heading ? MobileTheme.ink : row.amountColor
                }

                AmountText {
                    width: parent.width
                    visible: row.transfer
                    text: row.operation?.secondaryAmountText ?? ""
                    font.pixelSize: 12
                    color: MobileTheme.income
                }
            }
        }
    }

    RowLayout {
        id: compactRow

        anchors.left: parent.left
        anchors.right: actions.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: !row.landscape && !row.heading
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4

            MobileEditorialText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: row.operationTitle
                font.bold: true
                font.pixelSize: 16
            }

            MobileEditorialText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: row.operation?.descriptionText
                    ? row.accountText + " · " + row.operation.descriptionText : row.accountText
                color: MobileTheme.muted
                font.pixelSize: 13
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }

        ColumnLayout {
            Layout.preferredWidth: Math.min(160, row.cellWidth * 0.42)
            Layout.minimumWidth: 0
            spacing: 4

            AmountText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: row.operation?.primaryAmountText ?? ""
                font.pixelSize: 15
                color: row.amountColor
            }

            AmountText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: row.transfer
                text: row.operation?.secondaryAmountText ?? ""
                color: MobileTheme.income
            }

            MobileEditorialText {
                Layout.fillWidth: true
                text: row.operation?.dateText ?? ""
                font.family: MobileTheme.mono
                font.pixelSize: 12
                color: MobileTheme.muted
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    TabletRowActions {
        id: actions

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !row.heading
        enabled: !row.busy
        label: "Действия с операцией " + row.operationTitle
        onEditRequested: row.editRequested({
            id: row.operation.id,
            type: row.operation.type,
            accountId: row.operation.accountId,
            secondaryId: row.operation.secondaryId,
            amountInput: row.operation.amountInput,
            dateText: row.operation.dateText,
            descriptionText: row.operation.descriptionText
        })
        onRemoveRequested: row.removeRequested(row.operation.id, row.operation.descriptionText)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: row.heading
        height: 1
        color: MobileTheme.ink
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: row.heading ? MobileTheme.ink : MobileTheme.line
    }
}
