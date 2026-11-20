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

    implicitWidth: Math.max(130, Math.min(220, Math.max(balance.implicitWidth, detail.implicitWidth)))
    implicitHeight: compact ? 73 : 86
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: compact ? 8 : 11
    bottomPadding: compact ? 8 : 13
    Accessible.name: nameText + ", " + balanceText + ", " + detailText
    Accessible.selected: selected

    contentItem: ColumnLayout {
        spacing: chip.compact ? 2 : 4

        MobileEditorialText {
            Layout.fillWidth: true
            text: chip.nameText
            font.pixelSize: chip.compact ? 13 : 14
        }

        MobileEditorialText {
            id: balance

            Layout.fillWidth: true
            text: chip.balanceText
            font.family: MobileTheme.serif
            font.pixelSize: chip.compact ? 19 : 21
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 13
        }

        MobileEditorialText {
            id: detail

            Layout.fillWidth: true
            text: chip.detailText
            font.pixelSize: chip.compact ? 11 : 12
            color: chip.credit ? MobileTheme.historyExpense : MobileTheme.muted
        }
    }

    background: Rectangle {
        color: chip.down ? MobileTheme.soft : "transparent"
        border.width: chip.visualFocus ? 1 : 0
        border.color: MobileTheme.accent

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: chip.selected ? 2 : 1
            color: chip.selected ? MobileTheme.accent : MobileTheme.line
        }
    }
}
