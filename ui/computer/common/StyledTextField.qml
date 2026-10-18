import QtQuick
import QtQuick.Controls
import "EditorialStyle.js" as Appearance

TextField {
    id: control
    readonly property bool editorial: Appearance.desktop

    property color appTextColor: "#031528"
    property color appMutedColor: editorial ? "#59616a" : "#687483"
    property color appPanelColor: editorial ? "#f3eddf" : "#FFFFF8"
    property color appSoftColor: editorial ? "#f3eddf" : "#FFFFF0"
    property color appLineColor: editorial ? "#bbb5a8" : "#D8D7C7"
    property color appAccentColor: editorial ? "#031528" : "#315C9B"
    property color appOnAccentColor: editorial ? "#f3eddf" : "#FFFFFF"
    property int controlHeight: editorial ? 48 : 44
    // Compatibility flag; text fields use a soft outline without a shadow.
    property bool neo: false

    implicitHeight: controlHeight
    leftPadding: editorial ? 0 : 14
    rightPadding: editorial ? 0 : 14
    color: enabled ? appTextColor : appMutedColor
    placeholderTextColor: appMutedColor
    selectionColor: appAccentColor
    selectedTextColor: appOnAccentColor
    font.family: editorial ? "Arimo" : "Commissioner"
    font.pixelSize: editorial ? 16 : 14
    selectByMouse: true

    background: Rectangle {
        radius: control.editorial ? 0 : control.neo ? 8 : 11
        color: control.editorial ? "transparent" : control.activeFocus ? appPanelColor : appSoftColor
        opacity: control.enabled ? 1 : 0.62
        border.width: control.editorial ? 0 : 1
        border.color: control.appLineColor
        Rectangle {
            visible: control.editorial
            y: parent.height - 1
            width: parent.width
            height: 1
            color: control.activeFocus ? control.appAccentColor : control.appLineColor
        }
    }
}
