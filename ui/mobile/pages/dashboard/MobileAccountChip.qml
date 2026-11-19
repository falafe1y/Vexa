pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Basic.Button {
    id: chip

    property string recordId: ""
    property string nameText: ""
    property string balanceText: ""
    property string detailText: ""
    property bool credit: false
    property bool selected: false
    property bool compact: false

    implicitWidth: 165
    implicitHeight: compact ? 74 : 104
    padding: compact ? 8 : 12
    Accessible.name: nameText + ", " + balanceText + ", " + detailText
    Accessible.selected: selected

    contentItem: ColumnLayout {
        spacing: chip.compact ? 2 : 6

        MobileEditorialText {
            Layout.fillWidth: true
            text: chip.nameText
            font.pixelSize: chip.compact ? 13 : 14
            color: chip.selected ? MobileTheme.sidebar : MobileTheme.ink
        }

        MobileEditorialText {
            Layout.fillWidth: true
            text: chip.balanceText
            font.family: MobileTheme.serif
            font.pixelSize: chip.compact ? 19 : 21
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 13
            color: chip.selected ? MobileTheme.sidebar : MobileTheme.ink
        }

        Item { Layout.fillHeight: true }

        MobileEditorialText {
            Layout.fillWidth: true
            text: chip.detailText
            font.pixelSize: chip.compact ? 11 : 12
            color: chip.credit
                ? (chip.selected ? MobileTheme.selectedDebt : MobileTheme.historyExpense)
                : (chip.selected ? MobileTheme.selectedMuted : MobileTheme.muted)
        }
    }

    background: Rectangle {
        color: chip.selected ? MobileTheme.ink : chip.down ? MobileTheme.soft : "transparent"
        border.width: chip.visualFocus ? 2 : 1
        border.color: chip.visualFocus ? MobileTheme.accent
            : chip.selected ? MobileTheme.ink : MobileTheme.line
    }
}
