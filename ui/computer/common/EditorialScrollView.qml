import QtQuick
import QtQuick.Controls
import "EditorialStyle.js" as Appearance

ScrollView {
    id: view
    clip: true
    font.family: Appearance.desktop ? "Arimo" : "Commissioner"
    font.pixelSize: Appearance.desktop ? 16 : 14
    rightPadding: Appearance.desktop && ScrollBar.vertical.visible ? 16 : 0
    function revealFocusedItem() {
        const focused = view.Window.window ? view.Window.window.activeFocusItem : null;
        let ancestor = focused;
        while (ancestor && ancestor !== view)
            ancestor = ancestor.parent;
        const viewport = view.contentItem;
        if (ancestor !== view || !viewport || viewport.contentY === undefined)
            return;
        const top = focused.mapToItem(viewport.contentItem, 0, 0).y;
        const bottom = top + focused.height;
        let offset = viewport.contentY;
        if (top < offset)
            offset = top;
        else if (bottom > offset + viewport.height)
            offset = bottom - viewport.height;
        viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height, offset));
    }
    Connections {
        target: view.Window.window
        function onActiveFocusItemChanged() {
            Qt.callLater(view.revealFocusedItem);
        }
    }
    ScrollBar.vertical: StyledScrollBar {
        parent: view
        x: view.mirrored ? 0 : view.width - width
        y: view.topPadding
        height: view.availableHeight
        policy: Appearance.desktop ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    }
}
