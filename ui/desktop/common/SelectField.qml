import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Basic.ComboBox {
    id: control

    // Внешний вид можно изменить для конкретного поля.
    property real popupWidth: width
    property color textColor: DesktopTheme.ink
    property color hoverColor: DesktopTheme.accent
    property color backgroundColor: DesktopTheme.sidebar
    property color borderColor: DesktopTheme.line

    property bool underlined: false
    property string fieldLabel: ""
    readonly property bool underlineFocused: activeFocus || popup.visible
    readonly property bool labelRaised: underlineFocused || displayText.length > 0

    implicitHeight: underlined ? 36 : 42
    topPadding: underlined && fieldLabel.length > 0 ? 11 : padding
    bottomPadding: underlined && fieldLabel.length > 0 ? 4 : padding
    hoverEnabled: true
    font.family: DesktopTheme.sans
    font.pixelSize: 14

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: control.enabled && control.hovered
            ? control.hoverColor : control.textColor
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.underlined ? 0 : DesktopTheme.menuTextPadding
        rightPadding: 30
        elide: Text.ElideRight
    }

    indicator: Text {
        text: "▾"
        font.pixelSize: 12
        color: control.textColor

        anchors.right: parent.right
        anchors.rightMargin: control.underlined ? 0 : 12
        anchors.verticalCenter: parent.verticalCenter
    }

    background: Rectangle {
        color: control.underlined ? "transparent" : control.backgroundColor
        border.width: control.underlined ? 0 : 1
        border.color: control.activeFocus ? control.hoverColor : control.borderColor

        Text {
            visible: control.underlined && control.fieldLabel.length > 0
            width: parent.width - 30
            elide: Text.ElideRight
            text: control.fieldLabel
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
            color: DesktopTheme.ink
        }
    }

    delegate: Basic.ItemDelegate {
        id: option
        required property int index
        required property var model

        width: control.popupWidth - 2 * control.popup.padding
        height: DesktopTheme.menuItemHeight
        hoverEnabled: true

        contentItem: Text {
            text: option.model[control.textRole]
            font.family: control.font.family
            font.pixelSize: control.font.pixelSize
            font.bold: control.currentIndex === option.index
            color: !option.enabled
                ? DesktopTheme.muted
                : (option.hovered || option.highlighted)
                    ? control.hoverColor : control.textColor
            verticalAlignment: Text.AlignVCenter
            leftPadding: DesktopTheme.menuTextPadding
            elide: Text.ElideRight
        }

        background: Rectangle {
            color: control.backgroundColor
        }
    }

    popup: Basic.Popup {
        y: control.height - 1
        width: control.popupWidth
        padding: DesktopTheme.menuPadding

        background: Rectangle {
            color: control.backgroundColor
            border.width: 1
            border.color: control.borderColor
        }

        contentItem: ListView {
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            clip: true
        }
    }
}
