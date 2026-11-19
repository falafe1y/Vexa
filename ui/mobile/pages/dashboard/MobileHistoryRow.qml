pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Basic.ItemDelegate {
    id: row

    required property int type
    required property string recordId
    required property string dateText
    required property string accountId
    required property string secondaryId
    required property string amountInput
    required property string accountText
    required property string secondaryAccountText
    required property string categoryText
    required property string primaryAmountText
    required property string secondaryAmountText
    required property string descriptionText
    required property string iconText
    required property string historyTitle
    required property string historySubtitle
    required property string historyAmountText
    required property string historySecondaryAmountText
    property bool busy: false

    readonly property color amountColor: row.type === 0 ? MobileTheme.historyIncome
        : row.type === 1 ? MobileTheme.historyExpense : MobileTheme.historyTransfer
    readonly property string summary: row.type === 2
        ? row.accountText + " " + row.secondaryAccountText
          + " · " + row.primaryAmountText + " / " + row.secondaryAmountText
        : row.accountText + " · " + row.categoryText + " · " + row.primaryAmountText

    signal actionsRequested(var data)

    padding: 0
    topPadding: 10
    bottomPadding: 10
    implicitHeight: Math.max(66, implicitContentHeight + topPadding + bottomPadding)
    enabled: !busy
    Accessible.name: row.dateText + ", " + summary
        + (row.descriptionText.length ? ", " + row.descriptionText : "")

    function requestActions() {
        actionsRequested({
            id: row.recordId,
            type: row.type,
            accountId: row.accountId,
            secondaryId: row.secondaryId,
            amountInput: row.amountInput,
            dateText: row.dateText,
            descriptionText: row.descriptionText,
            summary: summary
        })
    }

    onClicked: requestActions()
    onPressAndHold: requestActions()

    contentItem: RowLayout {
        spacing: 11

        MobileCategoryIcon {
            initial: row.iconText
            transfer: row.type === 2
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 5

            MobileEditorialText {
                Layout.fillWidth: true
                text: row.historyTitle
                font.pixelSize: 16
            }

            MobileEditorialText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: row.historySubtitle
                font.pixelSize: 12
                color: MobileTheme.muted
            }
        }

        ColumnLayout {
            Layout.maximumWidth: Math.min(160, row.width * 0.43)
            Layout.minimumWidth: 0
            spacing: 5

            MobileEditorialText {
                Layout.fillWidth: true
                text: row.historyAmountText
                font.family: MobileTheme.mono
                font.pixelSize: row.width < 350 ? 13 : 14
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 11
                horizontalAlignment: Text.AlignRight
                color: row.amountColor
            }

            MobileEditorialText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: row.historySecondaryAmountText
                font.family: MobileTheme.mono
                font.pixelSize: 12
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 11
                horizontalAlignment: Text.AlignRight
                color: row.amountColor
            }
        }
    }

    background: Rectangle {
        color: row.down ? MobileTheme.sidebar : "transparent"
        border.width: row.visualFocus ? 1 : 0
        border.color: MobileTheme.accent
    }
}
