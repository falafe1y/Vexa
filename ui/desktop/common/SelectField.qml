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

    implicitHeight: 42
    hoverEnabled: true
    font.family: DesktopTheme.sans
    font.pixelSize: 14

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: control.enabled && control.hovered
            ? control.hoverColor : control.textColor
        verticalAlignment: Text.AlignVCenter
        leftPadding: DesktopTheme.menuTextPadding
        rightPadding: 30
        elide: Text.ElideRight
    }

    indicator: Text {
        text: "⌄"
        font.pixelSize: 20
        color: control.enabled && control.hovered
            ? control.hoverColor : control.textColor
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
    }

    background: Rectangle {
        color: control.backgroundColor
        border.width: 1
        border.color: control.activeFocus ? control.hoverColor : control.borderColor
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
