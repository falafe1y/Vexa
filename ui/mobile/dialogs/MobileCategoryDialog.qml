import QtQuick
import QtQuick.Layouts

MobileFormDialog {
    id: dialog

    required property var ledger
    property var editData: null
    property int categoryType: 0
    title: editData ? "Редактировать категорию" : "Новая категория"
    busy: ledger.commandPending
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
    onOpened: {
        if (sheetStyle)
            nameField.forceActiveFocus()
    }

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
            underlined: dialog.sheetStyle
            Accessible.name: "Название"
            placeholderText: "Например, Продукты"
        }

        MobileEditorialText { text: "Тип категории" }

        MobileSelectField {
            id: typeBox
            Layout.fillWidth: true
            underlined: dialog.sheetStyle
            Accessible.name: "Тип категории"
            textRole: "text"
            valueRole: "value"
            model: [{text: "Доход", value: 0}, {text: "Расход", value: 1}]
        }
    }

    footer: MobileDialogActions {
        errorText: dialog.errorText
        busy: dialog.busy
        sheetStyle: dialog.sheetStyle
        submitColor: dialog.sheetStyle ? MobileTheme.accent : MobileTheme.ink
        submitText: dialog.sheetStyle ? (dialog.editData ? "Сохранить" : "Добавить категорию")
            : (dialog.editData ? "СОХРАНИТЬ" : "СОЗДАТЬ")
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
