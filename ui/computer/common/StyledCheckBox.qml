import QtQuick
import QtQuick.Controls
import "EditorialStyle.js" as Appearance

CheckBox {
    id: control
    readonly property bool editorial: Appearance.desktop

    property bool neo: false
    readonly property int pressShift: !editorial && neo && down && enabled ? 1 : 0
    property color appTextColor: "#031528"
    property color appMutedColor: editorial ? "#59616a" : "#687483"
    property color appSoftColor: editorial ? "#f3eddf" : "#FFFFF0"
    property color appLineColor: editorial ? "#bbb5a8" : "#D8D7C7"
    property color appAccentColor: "#031528"
    property color appHoverColor: editorial ? "#e9e4d8" : "#E4E8F1"
    property color appOnAccentColor: editorial ? "#f3eddf" : "#FFFFFF"

    hoverEnabled: true
    font.family: editorial ? "Arimo" : "Commissioner"
    font.pixelSize: editorial ? 16 : 14
    spacing: editorial ? 12 : 10
    implicitHeight: editorial ? Math.max(40, implicitContentHeight + topPadding + bottomPadding) : 32

    indicator: Rectangle {
        transform: Translate {
            y: control.pressShift
        }
        HardShadow {
            visible: control.neo && !control.editorial
            depth: 3 - control.pressShift
            shadowColor: control.appAccentColor
        }
        implicitWidth: control.editorial ? 20 : 22
        implicitHeight: control.editorial ? 20 : 22
        x: control.leftPadding
        y: (control.height - height) / 2
        radius: control.editorial ? 0 : 6
        color: control.checked ? (control.hovered ? Qt.lighter(control.appAccentColor, 1.2) : control.appAccentColor) : (control.hovered ? control.appHoverColor : control.appSoftColor)
        opacity: control.enabled ? 1 : 0.55
        border.width: control.editorial ? 1 : control.checked && !control.neo && !control.visualFocus ? 0 : 1
        border.color: control.editorial ? control.appAccentColor : control.neo ? (control.checked ? control.appOnAccentColor : control.appAccentColor) : control.visualFocus ? (control.checked ? control.appOnAccentColor : control.appAccentColor) : control.appLineColor

        Text {
            anchors.centerIn: parent
            visible: control.checked
            text: "✓"
            color: control.appOnAccentColor
            font.pixelSize: 16
            font.weight: Font.Bold
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        color: control.enabled ? control.appTextColor : control.appMutedColor
        font.family: editorial ? "Arimo" : "Commissioner"
        font.pixelSize: editorial ? 16 : 14
        wrapMode: control.editorial ? Text.WordWrap : Text.NoWrap
        elide: control.editorial ? Text.ElideNone : Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
