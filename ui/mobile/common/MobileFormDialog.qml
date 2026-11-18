pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.Dialog {
    id: dialog

    property alias body: fields.data
    property string errorText: ""
    property real maximumWidth: Infinity
    property bool centered: false
    property bool sheetStyle: false
    property color sheetDimColor: "#9e031528"
    property bool showTitle: true
    property bool busy: false

    readonly property int inset: sheetStyle ? 0 : 8
    readonly property real usableHeight: {
        if (!parent)
            return 0
        const keyboard = InputMethod.keyboardRectangle
        if (!InputMethod.visible || keyboard.height <= 0)
            return parent.height

        // Qt for Android reports the keyboard rectangle in native pixels.
        const pixelRatio = Qt.platform.os === "android"
            ? (bodyScroll.hostWindow?.devicePixelRatio ?? bodyScroll.Screen.devicePixelRatio)
            : 1
        const keyboardTop = parent.mapFromItem(null, keyboard.x / pixelRatio, keyboard.y / pixelRatio).y
        return Math.max(0, Math.min(parent.height, keyboardTop))
    }

    width: parent ? Math.min(sheetStyle ? MobileTheme.phonePageWidth : maximumWidth,
                             Math.max(0, parent.width - 2 * inset)) : 0
    height: Math.min(implicitHeight, Math.max(0, usableHeight - (sheetStyle ? 10 : 2 * inset)))
    x: (sheetStyle || centered) && parent ? (parent.width - width) / 2 : inset
    y: Math.max(inset, centered ? (usableHeight - height) / 2 : usableHeight - height - inset)
    bottomPadding: sheetStyle && !footer ? 14 : 8
    topPadding: sheetStyle ? (showTitle ? 13 : 18) : 0
    leftPadding: MobileTheme.pagePadding
    rightPadding: MobileTheme.pagePadding
    spacing: sheetStyle ? 10 : 8
    contentHeight: fields.implicitHeight
    modal: true
    focus: true
    popupType: Basic.Popup.Item
    closePolicy: busy ? Basic.Popup.NoAutoClose
        : sheetStyle ? Basic.Popup.CloseOnEscape | Basic.Popup.CloseOnPressOutside
        : Basic.Popup.CloseOnEscape

    Basic.Overlay.modal: Rectangle {
        color: dialog.sheetStyle ? dialog.sheetDimColor : Qt.alpha(dialog.palette.shadow, 0.5)
    }

    onAboutToShow: bodyScroll.contentY = 0
    onAboutToHide: {
        if (InputMethod.visible)
            InputMethod.hide()
    }

    function revealFocusedField() {
        const field = bodyScroll.hostWindow?.activeFocusItem
        if (!opened || !field || bodyScroll.height <= 0)
            return

        let ancestor = field.parent
        while (ancestor && ancestor !== fields)
            ancestor = ancestor.parent
        if (!ancestor)
            return

        const top = field.mapToItem(fields, 0, 0).y - 6
        const bottom = top + field.height + 12
        const targetY = Math.max(bottom - bodyScroll.height, Math.min(top, bodyScroll.contentY))
        bodyScroll.contentY = Math.max(0, Math.min(targetY, bodyScroll.contentHeight - bodyScroll.height))
    }

    Connections {
        target: bodyScroll.hostWindow
        function onActiveFocusItemChanged() {
            Qt.callLater(dialog.revealFocusedField)
        }
    }

    contentItem: Flickable {
        id: bodyScroll

        readonly property var hostWindow: Window.window

        clip: true
        contentWidth: width
        contentHeight: fields.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        onHeightChanged: Qt.callLater(dialog.revealFocusedField)

        Column {
            id: fields
            width: bodyScroll.width
        }

        Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}
    }

    background: Rectangle {
        radius: dialog.sheetStyle ? 0 : 10
        color: MobileTheme.paper
        border.color: MobileTheme.ink
        border.width: 1
    }

    header: Item {
        visible: dialog.showTitle
        implicitHeight: !dialog.showTitle ? 0 : dialog.sheetStyle
            ? Math.max(44, titleLabel.implicitHeight) + 20 : titleLabel.implicitHeight

        MobileEditorialText {
            id: titleLabel

            anchors.left: parent.left
            anchors.leftMargin: MobileTheme.pagePadding
            anchors.right: closeButton.visible ? closeButton.left : parent.right
            anchors.rightMargin: closeButton.visible ? 8 : MobileTheme.pagePadding
            anchors.verticalCenter: closeButton.visible ? closeButton.verticalCenter : parent.verticalCenter
            text: dialog.title
            font.family: MobileTheme.serif
            font.pixelSize: dialog.sheetStyle ? (dialog.width < 350 ? 24 : 28) : 25
            font.bold: dialog.sheetStyle
            topPadding: dialog.sheetStyle ? 0 : 14
            bottomPadding: dialog.sheetStyle ? 0 : 8
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.Heading
        }

        Basic.Button {
            id: closeButton

            visible: dialog.sheetStyle
            enabled: !dialog.busy
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 3
            anchors.right: parent.right
            anchors.rightMargin: MobileTheme.pagePadding
            width: 44
            height: 44
            padding: 0
            text: "×"
            Accessible.name: "Закрыть"
            onClicked: dialog.close()

            contentItem: MobileEditorialText {
                text: closeButton.text
                font.pixelSize: 23
                horizontalAlignment: Text.AlignHCenter
            }

            background: Rectangle {
                color: closeButton.down ? MobileTheme.soft : MobileTheme.sidebar
                border.width: closeButton.visualFocus ? 2 : 1
                border.color: closeButton.visualFocus ? MobileTheme.accent : MobileTheme.line
            }
        }

        Rectangle {
            visible: dialog.sheetStyle
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: MobileTheme.pagePadding
            anchors.rightMargin: MobileTheme.pagePadding
            height: 1
            color: MobileTheme.ink
        }
    }
}
