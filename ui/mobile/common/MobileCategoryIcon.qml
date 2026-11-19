import QtQuick
import QtQuick.Shapes

Rectangle {
    id: icon

    required property string initial
    property bool transfer: false

    implicitWidth: 35
    implicitHeight: 35
    color: "transparent"
    border.width: 1
    border.color: MobileTheme.line
    Accessible.ignored: true

    MobileEditorialText {
        visible: !icon.transfer
        anchors.fill: parent
        text: icon.initial
        font.family: MobileTheme.serif
        font.pixelSize: 21
        horizontalAlignment: Text.AlignHCenter
    }

    Shape {
        anchors.centerIn: parent
        width: 21
        height: 21
        visible: icon.transfer

        ShapePath {
            strokeWidth: 1.4
            strokeColor: MobileTheme.historyTransfer
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M3 6h15 M14 2l4 4-4 4 M18 15H3 M7 11l-4 4 4 4" }
        }
    }
}
