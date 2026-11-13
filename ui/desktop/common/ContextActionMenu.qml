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
        text: "Редактировать"
        enabled: menu.editEnabled
        onTriggered: menu.editRequested()
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: 1
        color: DesktopTheme.line
    }

    PopupMenuItem {
        text: "Удалить"
        enabled: menu.removeEnabled
        hoverColor: DesktopTheme.accent
        onTriggered: menu.removeRequested()
    }
}
