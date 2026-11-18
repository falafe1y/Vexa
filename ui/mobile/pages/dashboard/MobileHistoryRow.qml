pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Basic.ItemDelegate {
    id: row

    property string recordId: ""
    property string dateText: ""
    property string accountId: ""
    property string secondaryId: ""
    property string amountInput: ""
    property int operationType: 0
    property string accountText: ""
    property string secondaryAccountText: ""
    property string categoryText: ""
    property string primaryAmountText: ""
    property string secondaryAmountText: ""
    property string descriptionText: ""

    readonly property bool transfer: operationType === 2
    readonly property string summary: transfer
        ? accountText + " " + secondaryAccountText + " · " + primaryAmountText + " / " + secondaryAmountText
        : accountText + " · " + categoryText + " · " + primaryAmountText

    signal actionsRequested(var data)

    padding: 0
    implicitHeight: details.implicitHeight
    Accessible.name: dateText + ", " + summary + (descriptionText.length ? ", " + descriptionText : "")

    function requestActions() {
        actionsRequested({
            id: recordId,
            type: operationType,
            accountId: accountId,
            secondaryId: secondaryId,
            amountInput: amountInput,
            dateText: dateText,
            descriptionText: descriptionText,
            summary: summary
        })
    }

    onClicked: requestActions()
    onPressAndHold: requestActions()

    component HistoryLine: RowLayout {
        id: line

        required property string account
        required property string category
        required property string amount
        property color amountColor: MobileTheme.ink

        Layout.fillWidth: true
        Layout.minimumHeight: 34
        spacing: 4

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.preferredWidth: 1.15
            text: line.account
            font.pixelSize: 13
        }

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: line.category
            font.pixelSize: 13
        }

        MobileEditorialText {
            Layout.preferredWidth: Math.max(76, line.width * 0.28)
            text: line.amount
            font.family: MobileTheme.mono
            font.pixelSize: 13
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 9
            color: line.amountColor
            horizontalAlignment: Text.AlignRight
        }
    }

    contentItem: ColumnLayout {
        id: details

        spacing: 0

        HistoryLine {
            account: row.accountText
            category: row.transfer ? "Перевод" : row.categoryText
            amount: row.primaryAmountText
            amountColor: row.transfer ? MobileTheme.ink
                : row.operationType === 0 ? MobileTheme.historyIncome : MobileTheme.historyExpense
        }

        HistoryLine {
            visible: row.transfer
            account: row.secondaryAccountText
            category: ""
            amount: row.secondaryAmountText
        }

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.bottomMargin: 5
            visible: text.length > 0
            text: row.descriptionText
            font.pixelSize: 12
            color: MobileTheme.muted
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }

    background: Rectangle {
        color: row.down ? MobileTheme.sidebar : "transparent"
        border.width: row.visualFocus ? 1 : 0
        border.color: MobileTheme.accent
    }
}
