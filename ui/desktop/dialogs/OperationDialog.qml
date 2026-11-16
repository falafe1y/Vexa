import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

FormDialog {
    id: dialog
    required property var ledger
    property int operationType: 0
    property string errorText: ""
    property var editData: null
    onClosed: editData = null
    readonly property bool isTransfer: operationType === 2
    title: (editData ? "Редактировать: " : "") +
        (operationType === 0 ? "Доход." : operationType === 1 ? "Расход." : "Перевод.")
    closePolicy: ledger.commandPending ? Popup.NoAutoClose : Popup.CloseOnEscape

    function openFor(type) {
        editData = null
        operationType = type
        errorText = ""
        amountField.text = ""
        descriptionField.text = ""
        dateField.text = ledger.currentDateText()
        accountBox.currentIndex = accountBox.count > 0 ? 0 : -1
        receiverBox.currentIndex = receiverBox.count > 1 ? 1 : -1
        categoryBox.currentIndex = categoryBox.count > 0 ? 0 : -1
        open()
    }

    function openForEdit(data) {
        editData = data
        operationType = data.type
        errorText = ""
        accountBox.currentIndex = accountBox.indexOfValue(data.accountId)
        if (data.type === 2)
            receiverBox.currentIndex = receiverBox.indexOfValue(data.secondaryId)
        else
            categoryBox.currentIndex = categoryBox.indexOfValue(data.secondaryId)
        amountField.text = data.amountInput
        dateField.text = data.dateText
        descriptionField.text = data.descriptionText
        open()
    }

    Connections {
        target: dialog.ledger
        function onCommandFinished(commandName, id) {
            if (dialog.visible && (commandName === "income"
                                  || commandName === "expense"
                                  || commandName === "transfer"
                                  || commandName === "updateOperation")) dialog.close()
        }
        function onErrorOccurred(message) {
            if (dialog.visible) dialog.errorText = message
        }
    }

    body: ColumnLayout {
        width: dialog.availableWidth
        enabled: !dialog.ledger.commandPending
        spacing: 12
        SelectField {
            id: accountBox
            underlined: true
            fieldLabel: dialog.isTransfer ? "Откуда" : "Счёт"
            Accessible.name: fieldLabel
            Layout.fillWidth: true
            model: dialog.ledger.accountsModel
            textRole: "name"
            valueRole: "id"
        }
        SelectField {
            id: receiverBox
            underlined: true
            fieldLabel: "Куда"
            Accessible.name: fieldLabel
            Layout.fillWidth: true
            visible: dialog.isTransfer
            model: dialog.ledger.accountsModel
            textRole: "name"
            valueRole: "id"
        }
        SelectField {
            id: categoryBox
            underlined: true
            fieldLabel: "Категория"
            Accessible.name: fieldLabel
            Layout.fillWidth: true
            visible: !dialog.isTransfer
            model: dialog.operationType === 0
                   ? dialog.ledger.incomeCategoriesModel
                   : dialog.ledger.expenseCategoriesModel
            textRole: "name"
            valueRole: "id"
        }
        EditorialText {
            Layout.fillWidth: true
            visible: !dialog.isTransfer && categoryBox.count === 0
            text: "Сначала добавьте категорию подходящего типа."
            wrapMode: Text.WordWrap
            color: DesktopTheme.muted
            font.pixelSize: 12
        }
        AmountField {
            id: amountField
            underlined: true
            Accessible.name: placeholderText
            Layout.fillWidth: true
            placeholderText: dialog.isTransfer
                ? "Сумма списания в валюте отправителя"
                : "Сумма в валюте счёта"
        }
        InputField {
            id: descriptionField
            placeholderText: "Описание"
            underlined: true
            Accessible.name: placeholderText
            Layout.fillWidth: true
            validator: RegularExpressionValidator {
                regularExpression: /^[\s\S]{0,50}$/
            }
        }
        InputField {
            id: dateField
            underlined: true
            placeholderText: "Дата"
            Accessible.name: placeholderText
            Layout.fillWidth: true
        }
        FormError { Layout.fillWidth: true; message: dialog.errorText }
    }

    footer: DialogActions {
        busy: dialog.ledger.commandPending
        submitText: dialog.editData ? "СОХРАНИТЬ" : "ДОБАВИТЬ"
        canSubmit: accountBox.currentIndex >= 0
                   && (dialog.isTransfer ? receiverBox.currentIndex >= 0
                                         : categoryBox.currentIndex >= 0)
        onCancelled: dialog.close()
        onSubmitted: {
            dialog.errorText = ""
            if (dialog.editData) {
                dialog.ledger.updateOperation(dialog.editData.id, dialog.operationType,
                    accountBox.currentValue,
                    dialog.isTransfer ? receiverBox.currentValue : categoryBox.currentValue,
                    amountField.normalizedText, dateField.text, descriptionField.text)
            } else if (dialog.operationType === 0) {
                dialog.ledger.addIncome(accountBox.currentValue, categoryBox.currentValue,
                    amountField.normalizedText, dateField.text, descriptionField.text)
            } else if (dialog.operationType === 1) {
                dialog.ledger.addExpense(accountBox.currentValue, categoryBox.currentValue,
                    amountField.normalizedText, dateField.text, descriptionField.text)
            } else {
                dialog.ledger.transfer(accountBox.currentValue, receiverBox.currentValue,
                    amountField.normalizedText, dateField.text, descriptionField.text)
            }
        }
    }
}
