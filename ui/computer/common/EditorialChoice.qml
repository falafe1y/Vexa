import QtQuick
import QtQuick.Controls
import "../dashboard"

ComboBox {
    id: control
    implicitWidth: 240
    implicitHeight: 48
    padding: 0
    opacity: enabled ? 1 : 0.45
    rightPadding: 24
    font.family: "Arimo"
    font.pixelSize: 16
    contentItem: EditorialText {
        text: control.displayText
        font: control.font
    }
    indicator: EditorialText {
        x: control.width - 16
        height: 48
        text: "⌄"
        font.pixelSize: 14
    }
    background: Item {
        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: "#031528"
        }
    }
    popup.background: Rectangle {
        color: "#f3eddf"
        border.color: "#031528"
    }
    delegate: ItemDelegate {
        required property int index
        width: control.width
        text: control.textAt(index)
        font: control.font
        highlighted: control.highlightedIndex === index
    }
}
