import QtQuick
import "../dashboard"

Item {
    id: section
    property int number: 1
    property string title: ""
    property string description: ""
    default property alias controls: controls.data
    readonly property int gap: width <= 1200 ? 32 : 48
    readonly property int leftWidth: Math.round((width - gap) * .36)
    implicitHeight: Math.max(copy.height, controls.height) + 64
    Column {
        id: copy
        x: 0
        y: 32
        width: section.leftWidth
        spacing: 12
        EditorialText {
            width: parent.width
            height: 24
            text: String(section.number).padStart(2, "0") + " / " + qsTr("НАСТРОЙКИ")
            font.family: "Cousine"
            font.pixelSize: 12
            color: "#59616a"
        }
        EditorialText {
            width: parent.width
            height: implicitHeight
            text: section.title
            font.family: "PT Serif"
            font.pixelSize: 32
            wrapMode: Text.WordWrap
        }
        EditorialText {
            width: parent.width
            height: implicitHeight
            text: section.description
            color: "#59616a"
            wrapMode: Text.WordWrap
        }
    }
    Column {
        id: controls
        x: section.leftWidth + section.gap
        y: 40
        width: section.width - x
        spacing: 16
    }
    Rectangle {
        y: parent.height - 1
        width: parent.width
        height: 1
        color: "#031528"
    }
}
