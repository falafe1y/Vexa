import QtQuick
import QtQuick.Controls

Button {
    id: chip
    property bool selected: false
    implicitHeight: 48
    leftPadding: 12
    rightPadding: 12
    font.family: MobileTheme.sans
    font.pixelSize: 16
    contentItem: MobileText {
        text: chip.text
        font: chip.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        color: chip.selected || chip.down ? MobileTheme.pale : "transparent"
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: chip.selected ? 2 : 1
            color: chip.selected ? MobileTheme.accent : MobileTheme.line
        }
    }
}
