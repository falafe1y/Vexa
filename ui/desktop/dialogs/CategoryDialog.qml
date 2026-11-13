import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

FormDialog {
    id: dialog
    required property var ledger
    property string errorText: ""
    property var editData: null
    title: editData ? "Редактировать категорию." : "Новая категория."
    onClosed: editData = null

    function openForEdit(data) {
        editData = data
        open()
    }
    closePolicy: ledger.commandPending ? Popup.NoAutoClose : Popup.CloseOnEscape

    onOpened: {
        errorText = ""
        nameField.text = editData ? editData.name : ""
        typeBox.currentIndex = editData ? typeBox.indexOfValue(editData.type) : 0
        nameField.forceActiveFocus()
    }

    Connections {
        target: dialog.ledger
        function onCommandFinished(commandName, id) {
            if (dialog.visible && (commandName === "createCategory" || commandName === "updateCategory")) dialog.close()
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
        submitText: dialog.editData ? "СОХРАНИТЬ" : "СОЗДАТЬ"
        onCancelled: dialog.close()
        onSubmitted: {
            dialog.errorText = ""
            if (dialog.editData)
                dialog.ledger.updateCategory(dialog.editData.id, nameField.text, typeBox.currentValue)
            else
                dialog.ledger.createCategory(nameField.text, typeBox.currentValue)
        }
    }
}
