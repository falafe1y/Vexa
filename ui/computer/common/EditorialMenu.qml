import QtQuick
import QtQuick.Controls

Menu {
    implicitWidth: 240
    padding: 4
    font.family: "Arimo"
    font.pixelSize: 16
    palette.window: "#f3eddf"
    palette.windowText: "#031528"
    palette.text: "#031528"
    palette.dark: "#031528"
    delegate: EditorialMenuItem {}
    background: Rectangle {
        color: "#f3eddf"
        border.color: "#031528"
    }
}
