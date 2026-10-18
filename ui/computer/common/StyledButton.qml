import QtQuick
import QtQuick.Controls
import "EditorialStyle.js" as Appearance

Button {
    id: control
    readonly property bool editorial: Appearance.desktop

    property bool primary: false
    property bool destructive: false
    // Kept for compatibility with existing button instances; outlines stay soft.
    property bool neo: false
    property bool dimWhenDisabled: true
    property int shadowDepth: 4
    property color appTextColor: "#031528"
    property color appMutedColor: editorial ? "#59616a" : "#687483"
    property color appPanelColor: editorial ? "#f3eddf" : "#FFFFF8"
    property color appSoftColor: editorial ? "#f3eddf" : "#FFFFF0"
    property color appLineColor: editorial ? "#bbb5a8" : "#D8D7C7"
    property color appAccentColor: "#031528"
    property color appHoverColor: editorial ? "#e9e4d8" : "#E4E8F1"
    property color appOnAccentColor: editorial ? "#f3eddf" : "#FFFFFF"
    property color appErrorColor: editorial ? "#b84932" : "#B94F48"
    property int cornerRadius: 9
    property int controlHeight: editorial ? 48 : 40

    // Ordinary buttons have no offset shadow or pressed translation.
    readonly property int pressShift: 0

    activeFocusOnTab: true
    hoverEnabled: true
    implicitHeight: controlHeight
    leftPadding: 16
    rightPadding: 16
    font.family: editorial ? "Arimo" : "Commissioner"
    font.pixelSize: editorial ? 16 : 14
    font.weight: Font.Medium

    contentItem: Text {
        text: control.text
        color: !control.enabled && control.dimWhenDisabled ? (control.editorial && (control.primary || control.destructive || control.highlighted) ? control.appOnAccentColor : control.appMutedColor) : !control.editorial && control.flat && control.destructive && !control.neo ? control.appErrorColor : control.primary || control.destructive || (control.editorial && control.highlighted) ? control.appOnAccentColor : control.appTextColor
        opacity: control.editorial || control.enabled || !control.dimWhenDisabled ? 1 : 0.62
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        transform: Translate {
            y: control.pressShift
        }
    }

    background: Rectangle {
        transform: Translate {
            y: control.pressShift
        }

        radius: control.editorial ? 0 : control.cornerRadius
        opacity: control.enabled || !control.dimWhenDisabled ? 1 : 0.55
        color: control.editorial ? (control.primary || control.destructive || control.highlighted ? (control.destructive ? control.appErrorColor : control.appAccentColor) : control.hovered || control.down ? control.appHoverColor : "transparent") : control.neo ? (control.destructive ? (control.down || control.hovered ? Qt.darker(control.appErrorColor, 1.08) : control.appErrorColor) : control.primary ? (control.down || control.hovered ? Qt.lighter(control.appAccentColor, 1.2) : control.appAccentColor) : control.hovered || control.down ? control.appHoverColor : control.appPanelColor) : control.flat ? (control.hovered ? control.appHoverColor : "transparent") : control.destructive ? (control.down || control.hovered ? Qt.darker(control.appErrorColor, 1.08) : control.appErrorColor) : control.primary ? (control.down || control.hovered ? Qt.lighter(control.appAccentColor, 1.2) : control.appAccentColor) : control.hovered ? control.appHoverColor : control.appSoftColor
        border.width: 1
        border.color: control.editorial ? control.appTextColor : control.appLineColor
    }
}
