import QtQuick
import QtQuick.Layouts
import "EditorialStyle.js" as Appearance

Text {
    readonly property bool editorial: Appearance.desktop
    property bool ruleVisible: true
    Layout.fillWidth: true
    color: "#031528"
    font.family: editorial ? "PT Serif" : "Commissioner"
    font.styleName: ""
    font.pixelSize: editorial ? 32 : 21
    font.italic: editorial
    font.bold: !editorial
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    bottomPadding: editorial && ruleVisible ? 20 : 0
    Rectangle {
        visible: parent.editorial && parent.ruleVisible
        x: parent.leftPadding
        y: parent.height - 1
        width: Math.max(0, parent.width - parent.leftPadding - parent.rightPadding)
        height: 1
        color: "#031528"
    }
}
