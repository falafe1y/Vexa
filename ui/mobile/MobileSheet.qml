import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: sheet
    property string title: ""
    default property alias content: body.data
    readonly property real keyboardTop: Qt.inputMethod.visible && Qt.inputMethod.keyboardRectangle.height > 0 ? Math.min(parent ? parent.height : 0, Qt.inputMethod.keyboardRectangle.y) : (parent ? parent.height : 0)
    readonly property real usableHeight: Math.max(0, keyboardTop)
    // Insets come from the overlay, which stays at the window origin. The sheet's own margins change while it slides.
    readonly property real insetTop: parent ? parent.SafeArea.margins.top : 0
    readonly property real insetBottom: parent ? parent.SafeArea.margins.bottom : 0
    readonly property real insetLeft: parent ? parent.SafeArea.margins.left : 0
    readonly property real insetRight: parent ? parent.SafeArea.margins.right : 0
    property real revealFactor: 0
    parent: Overlay.overlay
    modal: true
    focus: true
    dim: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: insetLeft
    width: (parent ? parent.width : 360) - insetLeft - insetRight
    // The top edge stays below the status bar and camera cutout, with the same 16 px gap as before.
    height: Math.min(Math.max(0, usableHeight - insetTop - 16), body.implicitHeight + 48 + insetBottom)
    y: usableHeight - height * revealFactor
    onAboutToShow: MobileBackStack.push(sheet)
    onAboutToHide: MobileBackStack.remove(sheet)
    Component.onDestruction: MobileBackStack.remove(sheet)
    enter: Transition {
        NumberAnimation {
            property: "revealFactor"
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "revealFactor"
            from: 1
            to: 0
            duration: 160
            easing.type: Easing.InCubic
        }
    }
    function revealFocus() {
        const item = scroll.Window.window ? scroll.Window.window.activeFocusItem : null;
        if (!item || !item.mapToItem)
            return;
        let ancestor = item;
        while (ancestor && ancestor !== body)
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        const top = item.mapToItem(scroll.contentItem, 0, 0).y;
        if (top < scroll.contentY + 16)
            scroll.contentY = Math.max(0, top - 16);
        else if (top + item.height > scroll.contentY + scroll.height - 16)
            scroll.contentY = Math.min(Math.max(0, scroll.contentHeight - scroll.height), top + item.height - scroll.height + 16);
    }
    onOpened: Qt.callLater(revealFocus)
    Connections {
        target: scroll.Window.window
        function onActiveFocusItemChanged() {
            Qt.callLater(sheet.revealFocus);
        }
    }
    Connections {
        target: Qt.inputMethod
        function onKeyboardRectangleChanged() {
            Qt.callLater(sheet.revealFocus);
        }
        function onVisibleChanged() {
            Qt.callLater(sheet.revealFocus);
        }
    }
    background: Rectangle {
        color: MobileTheme.canvas
        Rectangle {
            width: parent.width
            height: 2
            color: MobileTheme.accent
        }
    }
    contentItem: Flickable {
        id: scroll
        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        pixelAligned: true
        contentWidth: width
        contentHeight: body.implicitHeight + 48 + sheet.insetBottom
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
        ColumnLayout {
            id: body
            x: 20
            y: 24
            width: scroll.width - 40
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                visible: sheet.title.length > 0
                spacing: 12
                MobileText {
                    font.family: MobileTheme.serif
                    Layout.fillWidth: true
                    text: sheet.title
                    wrapMode: Text.Wrap
                    font.pixelSize: 32
                    font.italic: true
                }
                MobileIconButton {
                    icon: "close"
                    onClicked: sheet.close()
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: MobileTheme.accent
                visible: sheet.title.length > 0
                Layout.bottomMargin: 8
            }
        }
    }
}
