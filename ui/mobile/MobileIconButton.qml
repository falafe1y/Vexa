import QtQuick

Rectangle {
    id: button

    property string icon: ""
    signal clicked

    implicitWidth: 44
    implicitHeight: 44
    radius: MobileTheme.radiusControl
    color: tap.pressed ? MobileTheme.hover : MobileTheme.panel
    border.width: 0
    border.color: MobileTheme.line

    MobileIcon {
        anchors.centerIn: parent
        name: button.icon
        width: 20
        height: 20
        color: MobileTheme.accent
    }

    TapHandler {
        id: tap
        onTapped: button.clicked()
    }
}
