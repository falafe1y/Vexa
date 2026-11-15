pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.ComboBox {
    id: control

    property string placeholderText: "Выберите"
    property color backgroundColor: MobileTheme.sidebar
    property color borderColor: MobileTheme.line

    readonly property real hostHeight: Window.window?.height ?? 0

    implicitHeight: MobileTheme.touchSize
    padding: 0
    leftPadding: 0
    rightPadding: 0
    font.family: MobileTheme.sans
    font.pixelSize: 16
    opacity: enabled ? 1 : 0.55

    contentItem: MobileEditorialText {
        text: control.currentIndex < 0 ? control.placeholderText : control.displayText
        font: control.font
        leftPadding: MobileTheme.menuTextPadding
        rightPadding: 28
        color: control.currentIndex < 0 ? MobileTheme.muted : MobileTheme.ink
    }

    indicator: MobileEditorialText {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        font.pixelSize: 18
        color: MobileTheme.muted
    }

    background: Rectangle {
        radius: 6
        color: control.down ? MobileTheme.soft : control.backgroundColor
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? MobileTheme.accent : control.borderColor
    }

    delegate: Basic.ItemDelegate {
        id: option

        required property int index
        required property var model

        width: ListView.view.width
        implicitHeight: MobileTheme.menuItemHeight
        text: model[control.textRole]
        highlighted: control.highlightedIndex === index

        contentItem: MobileEditorialText {
            text: option.text
            font.family: control.font.family
            font.pixelSize: control.font.pixelSize
            font.bold: control.currentIndex === option.index
        }

        background: Rectangle {
            color: option.down || option.highlighted ? MobileTheme.soft : control.backgroundColor
        }
    }

    popup: Basic.Popup {
        id: choices

        y: control.height
        width: control.width
        height: Math.min(list.implicitHeight + topPadding + bottomPadding,
                         Math.max(MobileTheme.touchSize, control.hostHeight * 0.45))
        padding: MobileTheme.menuPadding
        margins: 8
        focus: true
        popupType: Basic.Popup.Item

        onAboutToShow: {
            if (InputMethod.visible)
                InputMethod.hide()
        }

        background: Rectangle {
            radius: 6
            color: control.backgroundColor
            border.width: 1
            border.color: control.borderColor
        }

        contentItem: ListView {
            id: list

            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}
        }
    }
}
