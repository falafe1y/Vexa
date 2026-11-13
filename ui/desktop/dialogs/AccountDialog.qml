import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

FormDialog {
    id: dialog
    required property var ledger
    property string errorText: ""
    property var editData: null
    title: editData ? "Редактировать счёт." : "Новый счёт."
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
        currencyBox.currentIndex = editData
            ? ledger.currencyCodes.indexOf(editData.currencyCode)
            : ledger.baseCurrencyIndex
        openingField.text = editData ? editData.openingInput : "0"
        limitField.text = editData ? editData.limitInput : "0"
        nameField.forceActiveFocus()
    }

    Connections {
        target: dialog.ledger
        function onCommandFinished(commandName, id) {
            if (dialog.visible && (commandName === "createAccount" || commandName === "updateAccount")) dialog.close()
        }
        function onErrorOccurred(message) {
            if (dialog.visible) dialog.errorText = message
        }
    }

    body: ColumnLayout {
        width: dialog.availableWidth
        enabled: !dialog.ledger.commandPending
        spacing: 8
        EditorialText { text: "Название" }
        InputField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Например, Наличные"
        }

        EditorialText { text: "Тип счета" }
        SelectField {
            id: typeBox
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            model: [
                {text: "Наличные", value: 0},
                {text: "Дебетовая карта", value: 1},
                {text: "Кредитная карта", value: 2}
            ]
        }
        EditorialText { text: "Валюта" }
        SelectField {
            id: currencyBox
            Layout.fillWidth: true
            model: dialog.ledger.currencyCodes
        }

        EditorialText {
            text: typeBox.currentValue === 2
                ? "Доступный остаток по кредитке"
                : "Начальный остаток"
        }
        AmountField {
            id: openingField
            Layout.fillWidth: true
            placeholderText: "0,00"
        }
        EditorialText {
            Layout.fillWidth: true
            visible: typeBox.currentValue === 2
            text: "Укажите доступную сумму, а не долг. Например, лимит 100000 и доступно 80000 означают долг 20000."
            color: DesktopTheme.muted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        EditorialText {
            visible: typeBox.currentValue === 2
            text: "Кредитный лимит"
        }
        AmountField {
            id: limitField
            Layout.fillWidth: true
            visible: typeBox.currentValue === 2
            placeholderText: "Например, 100000"
        }
        FormError { Layout.fillWidth: true; message: dialog.errorText }
    }

    footer: DialogActions {
        busy: dialog.ledger.commandPending
        submitText: dialog.editData ? "СОХРАНИТЬ" : "СОЗДАТЬ"
        onCancelled: dialog.close()
        onSubmitted: {
            dialog.errorText = ""
            if (dialog.editData) {
                dialog.ledger.updateAccount(dialog.editData.id, nameField.text,
                    typeBox.currentValue, currencyBox.currentText,
                    openingField.normalizedText,
                    typeBox.currentValue === 2 ? limitField.normalizedText : "0")
            } else {
                dialog.ledger.createAccount(nameField.text, typeBox.currentValue,
                    currencyBox.currentText, openingField.normalizedText,
                    typeBox.currentValue === 2 ? limitField.normalizedText : "0")
            }
        }
    }
}
