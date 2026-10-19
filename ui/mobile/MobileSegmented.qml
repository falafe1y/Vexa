import QtQuick
import QtQuick.Layouts

Rectangle {
    id: control

    property var options: []
    property var value
    signal activated(var chosen)

    implicitHeight: 48
    radius: MobileTheme.radiusControl
    color: MobileTheme.tableHeader
    border.width: 1
    border.color: MobileTheme.line

    RowLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        Repeater {
            model: control.options

            delegate: Rectangle {
                id: segment

                required property var modelData
                readonly property bool current: modelData.value === control.value

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 0
                color: segment.current ? MobileTheme.pale : "transparent"
                border.width: 0
                border.color: MobileTheme.line

                MobileText {
                    font.family: MobileTheme.mono
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 4
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: segment.modelData.label
                    color: segment.current ? MobileTheme.accent : MobileTheme.muted
                    font.pixelSize: 12
                    font.weight: segment.current ? Font.DemiBold : Font.Medium
                }

                TapHandler {
                    onTapped: control.activated(segment.modelData.value)
                }
            }
        }
    }
}
