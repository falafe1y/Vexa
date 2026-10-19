import QtQuick

Rectangle {
    id: track

    property real value: 0
    property color fill: MobileTheme.accent

    implicitWidth: 120
    implicitHeight: 4
    radius: 0
    color: MobileTheme.tableHeader
    border.width: 0
    border.color: MobileTheme.line
    clip: true

    Rectangle {
        height: track.height
        width: track.width * Math.max(0, Math.min(1, track.value))
        radius: 0
        color: track.value > 1 ? MobileTheme.red : track.fill
    }
}
