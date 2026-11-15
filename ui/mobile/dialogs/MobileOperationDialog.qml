import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

MobileFormDialog {
    id: dialog
    required property var ledger
    property int operationType: 0
    property var editData: null
    onClosed: editData = null
    readonly property bool isTransfer: operationType === 2
    title: (editData ? "Редактировать: " : "") +
        (operationType === 0 ? "Доход." : operationType === 1 ? "Расход." : "Перевод.")
    closePolicy: ledger.commandPending ? Basic.Popup.NoAutoClose : Basic.Popup.CloseOnEscape

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
        width: parent.width
        enabled: !dialog.ledger.commandPending
        spacing: 8
        MobileEditorialText { text: dialog.isTransfer ? "Счёт отправителя" : "Счёт" }
        MobileSelectField {
            id: accountBox
            Layout.fillWidth: true
            Accessible.name: dialog.isTransfer ? "Счёт отправителя" : "Счёт"
            model: dialog.ledger.accountsModel
            textRole: "name"
            valueRole: "id"
        }
        MobileEditorialText { visible: dialog.isTransfer; text: "Счёт получателя" }
        MobileSelectField {
            id: receiverBox
            Layout.fillWidth: true
            Accessible.name: "Счёт получателя"
            visible: dialog.isTransfer
            model: dialog.ledger.accountsModel
            textRole: "name"
            valueRole: "id"
        }
        MobileEditorialText { visible: !dialog.isTransfer; text: "Категория" }
        MobileSelectField {
            id: categoryBox
            Layout.fillWidth: true
            Accessible.name: "Категория"
            visible: !dialog.isTransfer
            model: dialog.operationType === 0
                   ? dialog.ledger.incomeCategoriesModel
                   : dialog.ledger.expenseCategoriesModel
            textRole: "name"
            valueRole: "id"
        }
        MobileEditorialText {
            Layout.fillWidth: true
            visible: !dialog.isTransfer && categoryBox.count === 0
            text: "Сначала добавьте категорию подходящего типа."
            wrapMode: Text.WordWrap
            color: MobileTheme.muted
            font.pixelSize: 12
        }
        MobileEditorialText {
            id: amountLabel

            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: dialog.isTransfer ? "Сумма списания в валюте отправителя" : "Сумма в валюте счёта"
        }
        MobileAmountField {
            id: amountField
            Layout.fillWidth: true
            Accessible.name: amountLabel.text
            placeholderText: "Например, 1500,50"
        }
        MobileEditorialText {
            Layout.fillWidth: true
            visible: dialog.isTransfer
            text: "Сумма зачисления рассчитывается по фиксированному курсу."
            font.pixelSize: 12
            color: MobileTheme.muted
            wrapMode: Text.WordWrap
        }
        MobileEditorialText { text: "Описание" }
        MobileInputField {
            id: descriptionField
            Layout.fillWidth: true
            Accessible.name: "Описание"
            maximumLength: 50
        }
        MobileEditorialText { text: "Дата" }
        MobileInputField {
            id: dateField
            Layout.fillWidth: true
            Accessible.name: "Дата"
            placeholderText: "ДД.ММ.ГГГГ"
            inputMask: "00.00.0000"
            inputMethodHints: Qt.ImhDigitsOnly
        }
    }

    footer: MobileDialogActions {
        errorText: dialog.errorText
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
