pragma ComponentBehavior: Bound
import QtQuick

MobileActionButton {
    id: actions

    required property string label
    signal editRequested()
    signal removeRequested()

    text: "⋯"
    flat: true
    font.pixelSize: 21
    Accessible.name: actions.label
    onClicked: contextMenu.open()

    MobileContextActionMenu {
        id: contextMenu

        editEnabled: actions.enabled
        removeEnabled: actions.enabled
        onEditRequested: actions.editRequested()
        onRemoveRequested: actions.removeRequested()
    }
}
