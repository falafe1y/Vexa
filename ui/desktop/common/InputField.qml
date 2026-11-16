import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Basic.TextField {
    id: control
    property bool underlined: false
    readonly property bool labelRaised: activeFocus || text.length > 0

    implicitHeight: underlined ? 36 : 42
    topPadding: underlined ? 11 : padding
    bottomPadding: underlined ? 4 : padding
    leftPadding: underlined ? 0 : padding + 4
    rightPadding: underlined ? 0 : padding
    padding: 12
    font.family: DesktopTheme.sans
    font.pixelSize: 14
    color: DesktopTheme.ink
    placeholderTextColor: underlined ? "transparent" : DesktopTheme.muted
    selectionColor: DesktopTheme.ink
    selectedTextColor: DesktopTheme.paper
    background: Rectangle {
        color: control.underlined ? "transparent" : DesktopTheme.sidebar
        border.width: control.underlined ? 0 : 1
        border.color: control.activeFocus ? DesktopTheme.accent : DesktopTheme.line

        Text {
            visible: control.underlined
            width: parent.width
            elide: Text.ElideRight
            text: control.placeholderText
            color: DesktopTheme.muted
            font.family: control.font.family
            font.pixelSize: control.font.pixelSize
            transformOrigin: Item.TopLeft

            y: control.labelRaised ? 0 : (parent.height - height) / 2
            scale: control.labelRaised ? 0.75 : 1

            Behavior on y {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            height: 1
            visible: control.underlined
            color: DesktopTheme.line
        }
    }
}
