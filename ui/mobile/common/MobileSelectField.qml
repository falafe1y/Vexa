pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.ComboBox {
    id: control

    property string placeholderText: "Выберите"
    property color backgroundColor: MobileTheme.sidebar
    property color borderColor: MobileTheme.line
    property bool underlined: false

    readonly property real hostHeight: Window.window?.height ?? 0

    implicitHeight: underlined ? 44 : MobileTheme.touchSize
    padding: 0
    leftPadding: 0
    rightPadding: 0
    font.family: MobileTheme.sans
    font.pixelSize: 16
    opacity: enabled ? 1 : 0.55

    contentItem: MobileEditorialText {
        text: control.currentIndex < 0 ? control.placeholderText : control.displayText
        font: control.font
        leftPadding: control.underlined ? 0 : MobileTheme.menuTextPadding
        rightPadding: control.underlined ? 19 : 28
        color: control.currentIndex < 0 ? MobileTheme.muted : MobileTheme.ink
    }

    indicator: MobileEditorialText {
        anchors.right: parent.right
        anchors.rightMargin: control.underlined ? 4 : 10
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        font.pixelSize: 18
        color: MobileTheme.muted
    }

    background: Rectangle {
        radius: 6
        color: control.down ? MobileTheme.soft : control.underlined ? "transparent" : control.backgroundColor
        border.width: control.underlined ? 0 : control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? MobileTheme.accent : control.borderColor

        Rectangle {
            visible: control.underlined
            anchors.bottom: parent.bottom
            width: parent.width
            height: control.visualFocus ? 2 : 1
            color: control.visualFocus ? MobileTheme.accent : MobileTheme.ink
        }
    }

    delegate: Basic.ItemDelegate {
        id: option

        required property int index
        required property var model

        width: ListView.view.width
        implicitHeight: MobileTheme.menuItemHeight
        text: control.textRole.length ? model[control.textRole] : model.modelData
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
            radius: control.underlined ? 0 : 6
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
