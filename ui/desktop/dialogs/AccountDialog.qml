import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
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
        openingField.text = editData ? editData.openingInput : ""
        limitField.text = editData ? editData.limitInput : ""
        includeDebtCheck.checked = editData?.includeDebtInTotal ?? true
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
        spacing: 12

        InputField {
            id: nameField
            underlined: true
            Layout.fillWidth: true
            placeholderText: "Название счёта"
            Accessible.name: placeholderText
        }

        Row {
            id: row
            Layout.fillWidth: true
            spacing: 12

            readonly property real availableWidth: Math.max(0, width - spacing)

            SelectField {
                id: typeBox
                underlined: true
                fieldLabel: "Тип счета"
                Accessible.name: "Тип счёта"
                width: Math.round(row.availableWidth * 2 / 3)
                textRole: "text"
                valueRole: "value"
                model: [
                    {text: "Наличные", value: 0},
                    {text: "Дебетовая карта", value: 1},
                    {text: "Кредитная карта", value: 2}
                ]
            }

            SelectField {
                id: currencyBox
                underlined: true
                fieldLabel: "Валюта"
                Accessible.name: "Валюта"
                width: row.availableWidth - typeBox.width
                model: dialog.ledger.currencyCodes
            }
        }

        AmountField {
            id: openingField
            underlined: true
            Layout.fillWidth: true
            placeholderText: typeBox.currentValue === 2
                ? "Доступный остаток по кредитке"
                : "Начальный остаток"
            Accessible.name: placeholderText
        }
        AmountField {
            id: limitField
            underlined: true
            Layout.fillWidth: true
            visible: typeBox.currentValue === 2
            placeholderText: "Кредитный лимит"
            Accessible.name: placeholderText
        }
        Basic.CheckBox {
            id: includeDebtCheck
            Layout.fillWidth: true
            visible: typeBox.currentValue === 2
            text: "Учитывать долг в общем остатке"
            font.pixelSize: 14
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
                    openingField.normalizedText || "0",
                    typeBox.currentValue === 2 ? (limitField.normalizedText || "0") : "0",
                    includeDebtCheck.checked)
            } else {
                dialog.ledger.createAccount(nameField.text, typeBox.currentValue,
                    currencyBox.currentText, openingField.normalizedText || "0",
                    typeBox.currentValue === 2 ? (limitField.normalizedText || "0") : "0",
                    includeDebtCheck.checked)
            }
        }
    }
}
