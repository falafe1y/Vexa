import QtQuick
import QtQuick.Controls
import "../dashboard"

CheckBox {
    id: control
    implicitHeight: 40
    padding: 0
    spacing: 12
    font.family: "Arimo"
    font.pixelSize: 14
    indicator: Rectangle {
        x: 0
        y: (control.height - height) / 2
        width: 16
        height: 16
        radius: 2
        color: control.checked || control.checkState === Qt.PartiallyChecked ? "#031528" : "transparent"
        border.width: 1
        border.color: "#687483"
        Text {
            anchors.centerIn: parent
            text: control.checkState === Qt.PartiallyChecked ? "−" : "✓"
            visible: control.checkState !== Qt.Unchecked
            color: "#f3eddf"
            font.pixelSize: 14
        }
    }
    contentItem: EditorialText {
        text: control.text
        font: control.font
        leftPadding: 28
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
