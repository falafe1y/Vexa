import QtQuick
import QtQuick.Controls

TextField {
    id: control
    implicitWidth: 120
    implicitHeight: 48
    padding: 8
    leftPadding: 0
    rightPadding: 0
    font.family: "Arimo"
    font.pixelSize: 16
    color: "#031528"
    selectionColor: "#031528"
    selectedTextColor: "#f3eddf"
    placeholderTextColor: "#59616a"
    selectByMouse: true
    opacity: enabled ? 1 : 0.45
    background: Item {
        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: "#031528"
        }
    }
}
