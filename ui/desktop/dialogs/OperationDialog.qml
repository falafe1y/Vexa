import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

FormDialog {
    id: dialog
    required property var ledger
    property int operationType: 0
    property string errorText: ""
    readonly property bool isTransfer: operationType === 2
    title: operationType === 0 ? "Доход." : operationType === 1 ? "Расход." : "Перевод."
    closePolicy: ledger.commandPending ? Popup.NoAutoClose : Popup.CloseOnEscape

    function openFor(type) {
        operationType = type
        errorText = ""
        amountField.text = ""
        dateField.text = ledger.currentDateText()
        accountBox.currentIndex = accountBox.count > 0 ? 0 : -1
        receiverBox.currentIndex = receiverBox.count > 1 ? 1 : -1
        categoryBox.currentIndex = categoryBox.count > 0 ? 0 : -1
        open()
    }

    Connections {
        target: dialog.ledger
        function onCommandFinished(commandName, id) {
            if (dialog.visible && (commandName === "income"
                                  || commandName === "expense"
                                  || commandName === "transfer")) dialog.close()
        }
        function onErrorOccurred(message) {
            if (dialog.visible) dialog.errorText = message
        }
    }

    body: ColumnLayout {
        width: dialog.availableWidth
        enabled: !dialog.ledger.commandPending
        spacing: 10
        EditorialText { text: dialog.isTransfer ? "Счет отправителя" : "Счет" }
        SelectField {
            id: accountBox
            Layout.fillWidth: true
            model: dialog.ledger.accountsModel
            textRole: "name"
            valueRole: "id"
        }
        EditorialText { visible: dialog.isTransfer; text: "Счет получателя" }
        SelectField {
            id: receiverBox
            Layout.fillWidth: true
            visible: dialog.isTransfer
            model: dialog.ledger.accountsModel
            textRole: "name"
            valueRole: "id"
        }
        EditorialText { visible: !dialog.isTransfer; text: "Категория" }
        SelectField {
            id: categoryBox
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
        EditorialText {
            text: dialog.isTransfer ? "Сумма списания в валюте отправителя" : "Сумма в валюте счета"
        }
        AmountField {
            id: amountField
            Layout.fillWidth: true
            placeholderText: "Например, 1500,50"
        }
        EditorialText {
            Layout.fillWidth: true
            visible: dialog.isTransfer
            text: "Зачисление рассчитает сервис по фиксированному курсу."
            font.pixelSize: 12
            color: DesktopTheme.muted
            wrapMode: Text.WordWrap
        }
        EditorialText { text: "Дата" }
        InputField {
            id: dateField
            Layout.fillWidth: true
            placeholderText: "ГГГГ-ММ-ДД"
        }
        FormError { Layout.fillWidth: true; message: dialog.errorText }
    }

    footer: DialogActions {
        busy: dialog.ledger.commandPending
        submitText: "ДОБАВИТЬ"
        canSubmit: accountBox.currentIndex >= 0
                   && (dialog.isTransfer ? receiverBox.currentIndex >= 0
                                         : categoryBox.currentIndex >= 0)
        onCancelled: dialog.close()
        onSubmitted: {
            dialog.errorText = ""
            if (dialog.operationType === 0) {
                dialog.ledger.addIncome(accountBox.currentValue, categoryBox.currentValue,
                    amountField.normalizedText, dateField.text)
            } else if (dialog.operationType === 1) {
                dialog.ledger.addExpense(accountBox.currentValue, categoryBox.currentValue,
                    amountField.normalizedText, dateField.text)
            } else {
                dialog.ledger.transfer(accountBox.currentValue, receiverBox.currentValue,
                    amountField.normalizedText, dateField.text)
            }
        }
    }
}
