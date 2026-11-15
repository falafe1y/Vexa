pragma ComponentBehavior: Bound
import QtQuick

MobileActionButton {
    id: button

    required property bool landscape
    required property var ledger
    signal operationRequested(int type)

    text: "+ НОВАЯ ОПЕРАЦИЯ"
    outlined: landscape
    enabled: ledger.canAddOperation
    onClicked: operationMenu.open()

    onVisibleChanged: {
        if (!visible)
            operationMenu.close()
    }

    MobilePopupMenu {
        id: operationMenu

        parent: button
        width: button.landscape ? Math.max(button.width, implicitWidth) : button.width
        x: button.width - width
        y: button.landscape ? button.height : -height - 6

        MobilePopupMenuItem {
            text: "Доход"
            onTriggered: button.operationRequested(0)
        }

        MobilePopupMenuItem {
            text: "Расход"
            onTriggered: button.operationRequested(1)
        }

        MobilePopupMenuItem {
            text: "Перевод"
            enabled: button.ledger.canTransfer
            onTriggered: button.operationRequested(2)
        }
    }
}
