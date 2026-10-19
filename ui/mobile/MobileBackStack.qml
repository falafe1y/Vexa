pragma Singleton
import QtQuick

// Open popups, oldest first. Android Back closes the newest one before it navigates the pages underneath.
QtObject {
    id: stack
    property var popups: []
    readonly property int count: popups.length

    function push(popup) {
        if (popups.indexOf(popup) < 0)
            popups = popups.concat([popup]);
    }

    function remove(popup) {
        if (popups.indexOf(popup) >= 0)
            popups = popups.filter(function (item) { return item !== popup; });
    }

    // Returns true when a popup was closed, so the Back press is consumed.
    function closeTop() {
        while (popups.length > 0) {
            const top = popups[popups.length - 1];
            remove(top);
            if (top.visible) {
                top.close();
                return true;
            }
        }
        return false;
    }
}
