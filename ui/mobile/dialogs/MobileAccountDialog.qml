import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

MobileFormDialog {
    id: dialog

    required property var ledger
    property var editData: null
    title: editData ? "Редактировать счёт" : "Новый счёт"
    busy: ledger.commandPending
    onClosed: editData = null

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
        typeBox.currentIndex = editData ? typeBox.indexOfValue(editData.type) : 0
        currencyBox.currentIndex = editData
            ? ledger.currencyCodes.indexOf(editData.currencyCode)
            : ledger.baseCurrencyIndex
        openingField.text = editData ? editData.openingInput : "0"
        limitField.text = editData ? editData.limitInput : "0"
        includeDebtCheck.checked = editData?.includeDebtInTotal ?? true
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
        width: parent.width
        enabled: !dialog.ledger.commandPending
        spacing: 8

        MobileEditorialText { text: "Название" }

        MobileInputField {
            id: nameField
            Layout.fillWidth: true
            underlined: dialog.sheetStyle
            Accessible.name: "Название"
            placeholderText: "Например, Наличные"
        }

        GridLayout {
            Layout.fillWidth: true
            columns: dialog.sheetStyle ? 2 : 1
            columnSpacing: 8
            rowSpacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: dialog.sheetStyle ? 4 : 8

                MobileEditorialText { text: "Тип счёта" }

                MobileSelectField {
                    id: typeBox
                    Layout.fillWidth: true
                    underlined: dialog.sheetStyle
                    Accessible.name: "Тип счёта"
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        {text: "Наличные", value: 0},
                        {text: "Дебетовая карта", value: 1},
                        {text: "Кредитная карта", value: 2}
                    ]
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: dialog.sheetStyle ? 4 : 8

                MobileEditorialText { text: "Валюта" }

                MobileSelectField {
                    id: currencyBox
                    Layout.fillWidth: true
                    underlined: dialog.sheetStyle
                    Accessible.name: "Валюта"
                    model: dialog.ledger.currencyCodes
                }
            }
        }

        MobileEditorialText {
            id: openingLabel

            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: typeBox.currentValue === 2
                ? "Доступный остаток по кредитке"
                : "Начальный остаток"
        }
        MobileAmountField {
            id: openingField
            Layout.fillWidth: true
            underlined: dialog.sheetStyle
            Accessible.name: openingLabel.text
            placeholderText: "0,00"
        }
        MobileEditorialText {
            Layout.fillWidth: true
            visible: !dialog.sheetStyle && typeBox.currentValue === 2
            text: "Например, при лимите 100 000 и доступном остатке 80 000 долг составит 20 000."
            color: MobileTheme.muted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        MobileEditorialText {
            visible: typeBox.currentValue === 2
            text: "Кредитный лимит"
        }
        MobileAmountField {
            id: limitField
            Layout.fillWidth: true
            underlined: dialog.sheetStyle
            Accessible.name: "Кредитный лимит"
            visible: typeBox.currentValue === 2
            placeholderText: "Например, 100000"
        }
        Basic.CheckBox {
            id: includeDebtCheck
            Layout.fillWidth: true
            visible: typeBox.currentValue === 2
            text: "Учитывать долг в общем остатке"
            font.family: MobileTheme.sans
            font.pixelSize: 14
            Layout.minimumHeight: MobileTheme.touchSize
        }
    }

    footer: MobileDialogActions {
        errorText: dialog.errorText
        busy: dialog.busy
        sheetStyle: dialog.sheetStyle
        submitColor: dialog.sheetStyle ? MobileTheme.accent : MobileTheme.ink
        submitText: dialog.sheetStyle ? (dialog.editData ? "Сохранить" : "Добавить счёт")
            : (dialog.editData ? "СОХРАНИТЬ" : "СОЗДАТЬ")
        onCancelled: dialog.close()
        onSubmitted: {
            dialog.errorText = ""
            if (dialog.editData) {
                dialog.ledger.updateAccount(dialog.editData.id, nameField.text,
                    typeBox.currentValue, currencyBox.currentText,
                    openingField.normalizedText,
                    typeBox.currentValue === 2 ? limitField.normalizedText : "0",
                    includeDebtCheck.checked)
            } else {
                dialog.ledger.createAccount(nameField.text, typeBox.currentValue,
                    currencyBox.currentText, openingField.normalizedText,
                    typeBox.currentValue === 2 ? limitField.normalizedText : "0",
                    includeDebtCheck.checked)
            }
        }
    }
}
