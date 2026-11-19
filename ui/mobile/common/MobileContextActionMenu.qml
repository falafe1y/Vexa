import QtQuick

MobilePopupMenu {
    id: menu

    property bool historyEnabled: false
    signal historyRequested()

    property bool removeEnabled: true
    property bool editEnabled: true
    signal removeRequested()
    signal editRequested()

    x: parent.width - width
    y: parent.height

    MobilePopupMenuItem {
        visible: menu.historyEnabled
        text: "История операций"
        onTriggered: menu.historyRequested()
    }

    MobilePopupMenuItem {
        text: "Редактировать"
        enabled: menu.editEnabled
        onTriggered: menu.editRequested()
    }

    MobilePopupMenuItem {
        text: "Удалить"
        enabled: menu.removeEnabled
        textColor: MobileTheme.accent
        onTriggered: menu.removeRequested()
    }
}
