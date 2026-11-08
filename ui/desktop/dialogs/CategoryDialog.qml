import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

FormDialog {
    id: dialog
    required property var ledger
    property string errorText: ""
    title: "Новая категория."
    closePolicy: ledger.commandPending ? Popup.NoAutoClose : Popup.CloseOnEscape

    onOpened: {
        errorText = ""
        nameField.text = ""
        typeBox.currentIndex = 0
        nameField.forceActiveFocus()
    }

    Connections {
        target: dialog.ledger
        function onCommandFinished(commandName, id) {
            if (dialog.visible && commandName === "createCategory") dialog.close()
        }
        function onErrorOccurred(message) {
            if (dialog.visible) dialog.errorText = message
        }
    }

    body: ColumnLayout {
        width: dialog.availableWidth
        enabled: !dialog.ledger.commandPending
        spacing: 10
        EditorialText { text: "Название" }
        InputField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Например, Продукты"
        }
        EditorialText { text: "Тип категории" }
        SelectField {
            id: typeBox
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: [{text: "Доход", value: 0}, {text: "Расход", value: 1}]
        }
        FormError { Layout.fillWidth: true; message: dialog.errorText }
    }

    footer: DialogActions {
        busy: dialog.ledger.commandPending
        submitText: "СОЗДАТЬ"
        onCancelled: dialog.close()
        onSubmitted: {
            dialog.errorText = ""
            dialog.ledger.createCategory(nameField.text, typeBox.currentValue)
        }
    }
}
