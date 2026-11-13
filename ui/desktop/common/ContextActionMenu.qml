import QtQuick
import UI

// Reusable context menu for records. The owning delegate supplies the action.
PopupMenu {
    id: menu

    property bool removeEnabled: true
    property bool editEnabled: true
    signal removeRequested()
    signal editRequested()

    width: 176

    // Coordinates are local to the Item containing this menu.
    function openAt(localX, localY) {
        menu.x = Math.round(localX)
        menu.y = Math.round(localY)
        menu.open()
    }

    PopupMenuItem {
        text: "РЕДАКТИРОВАТЬ"
        enabled: menu.editEnabled
        onTriggered: menu.editRequested()
    }

    PopupMenuItem {
        text: "УДАЛИТЬ"
        enabled: menu.removeEnabled
        hoverColor: DesktopTheme.accent
        onTriggered: menu.removeRequested()
    }
}
