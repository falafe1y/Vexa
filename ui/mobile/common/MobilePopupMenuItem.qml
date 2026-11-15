import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.MenuItem {
    id: control

    property color textColor: MobileTheme.ink

    implicitHeight: MobileTheme.menuItemHeight
    leftPadding: MobileTheme.menuTextPadding
    rightPadding: MobileTheme.menuTextPadding

    contentItem: MobileEditorialText {
        text: control.text
        font.pixelSize: 16
        color: control.enabled ? control.textColor : MobileTheme.muted
    }

    background: Rectangle {
        color: control.down || control.highlighted ? MobileTheme.soft : "transparent"
    }
}
