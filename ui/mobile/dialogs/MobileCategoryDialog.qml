import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

MobileFormDialog {
    id: dialog
    required property var ledger
    property var editData: null
    property int categoryType: 0
    title: editData ? "Редактировать категорию." : "Новая категория."
    onClosed: editData = null

    function openFor(type) {
        categoryType = type
        editData = null
        open()
    }

    function openForEdit(data) {
        editData = data
        open()
    }
    closePolicy: ledger.commandPending ? Basic.Popup.NoAutoClose : Basic.Popup.CloseOnEscape

    onAboutToShow: {
        errorText = ""
        nameField.text = editData ? editData.name : ""
        typeBox.currentIndex = editData ? typeBox.indexOfValue(editData.type) : categoryType
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
        width: parent.width
        enabled: !dialog.ledger.commandPending
        spacing: 8
        MobileEditorialText { text: "Название" }
        MobileInputField {
            id: nameField
            Layout.fillWidth: true
            Accessible.name: "Название"
            placeholderText: "Например, Продукты"
        }
        MobileEditorialText { text: "Тип категории" }
        MobileSelectField {
            id: typeBox
            Layout.fillWidth: true
            Accessible.name: "Тип категории"
            textRole: "text"
            valueRole: "value"
            model: [{text: "Доход", value: 0}, {text: "Расход", value: 1}]
        }
    }

    footer: MobileDialogActions {
        errorText: dialog.errorText
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
