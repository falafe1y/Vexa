import QtQuick
import QtQuick.Layouts
import UI

RowLayout {
    id: actions
    property bool busy: false
    property bool canSubmit: true
    property string submitText: "СОХРАНИТЬ"
    signal cancelled()
    signal submitted()
    spacing: 8
    Item { Layout.fillWidth: true }
    ActionButton {
        Layout.bottomMargin: 20
        text: "ОТМЕНА"
        outlined: false
        enabled: !actions.busy
        onClicked: actions.cancelled()
    }
    ActionButton {
        Layout.rightMargin: 24
        Layout.bottomMargin: 20
        text: actions.busy ? "СОХРАНЕНИЕ…" : actions.submitText
        enabled: !actions.busy && actions.canSubmit
        onClicked: actions.submitted()
    }
}
