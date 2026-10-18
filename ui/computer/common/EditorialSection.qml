import QtQuick
import "../dashboard"

Item {
    id: section
    property int number: 1
    property string title: ""
    property string note: ""
    implicitHeight: 40
    EditorialText {
        width: 32
        height: parent.height
        text: String(section.number).padStart(2, "0") + "."
        font.family: "Cousine"
        font.pixelSize: 12
        color: "#b84932"
    }
    EditorialText {
        x: 32
        height: parent.height
        width: Math.max(0, parent.width - x - (note.visible ? note.width + 16 : 0))
        text: section.title.toUpperCase()
        font.pixelSize: 16
        font.bold: true
    }
    EditorialText {
        id: note
        anchors.right: parent.right
        height: parent.height
        visible: text !== ""
        text: section.note
        font.family: "Cousine"
        font.pixelSize: 12
        color: "#59616a"
    }
}
