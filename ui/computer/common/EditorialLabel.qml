import QtQuick
import QtQuick.Controls
import "EditorialStyle.js" as Appearance

Label {
    readonly property bool editorial: Appearance.desktop
    color: "#031528"
    font.family: editorial ? "Arimo" : "Commissioner"
    font.styleName: ""
    font.pixelSize: editorial ? 16 : 14
}
