import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.Dialog {
    id: dialog

    property alias body: fields.data
    property string errorText: ""

    readonly property int inset: 8
    readonly property real usableHeight: {
        if (!parent)
            return 0
        const keyboard = InputMethod.keyboardRectangle
        if (!InputMethod.visible || keyboard.height <= 0)
            return parent.height
        const keyboardTop = parent.mapFromItem(null, keyboard.x, keyboard.y).y
        return Math.max(0, Math.min(parent.height, keyboardTop))
    }

    width: parent ? Math.max(0, parent.width - 2 * inset) : 0
    height: Math.min(implicitHeight, Math.max(0, usableHeight - 2 * inset))
    x: inset
    y: Math.max(inset, usableHeight - height - inset)
    bottomPadding: 8
    topPadding: 0
    leftPadding: MobileTheme.pagePadding
    rightPadding: MobileTheme.pagePadding
    spacing: 8
    contentHeight: fields.implicitHeight
    modal: true
    focus: true
    popupType: Basic.Popup.Item

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
        radius: 10
        color: MobileTheme.paper
        border.color: MobileTheme.ink
        border.width: 1
    }

    header: MobileEditorialText {
        text: dialog.title
        font.family: MobileTheme.serif
        font.pixelSize: 25
        leftPadding: MobileTheme.pagePadding
        rightPadding: MobileTheme.pagePadding
        topPadding: 14
        bottomPadding: 8
        wrapMode: Text.WordWrap
    }
}
