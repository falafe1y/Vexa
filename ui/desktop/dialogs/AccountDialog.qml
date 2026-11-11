import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

FormDialog {
    id: dialog
    required property var ledger
    property string errorText: ""
    title: "Новый счет."
    closePolicy: ledger.commandPending ? Popup.NoAutoClose : Popup.CloseOnEscape

    onOpened: {
        errorText = ""
        nameField.text = ""
        typeBox.currentIndex = 0
        currencyBox.currentIndex = ledger.baseCurrencyIndex
        openingField.text = "0"
        limitField.text = "0"
        nameField.forceActiveFocus()
    }

    Connections {
        target: dialog.ledger
        function onCommandFinished(commandName, id) {
            if (dialog.visible && commandName === "createAccount") dialog.close()
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

        EditorialText { text: "Начальный остаток" }
        InputField {
            id: openingField
            Layout.fillWidth: true
            placeholderText: "0,00"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        EditorialText {
            Layout.fillWidth: true
            visible: typeBox.currentValue === 2
            text: "Уже есть долг 60 000? Укажите остаток -60000."
            color: DesktopTheme.muted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        EditorialText {
            visible: typeBox.currentValue === 2
            text: "Кредитный лимит"
        }
        InputField {
            id: limitField
            Layout.fillWidth: true
            visible: typeBox.currentValue === 2
            placeholderText: "Например, 90000"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        FormError { Layout.fillWidth: true; message: dialog.errorText }
    }

    footer: DialogActions {
        busy: dialog.ledger.commandPending
        submitText: "СОЗДАТЬ"
        onCancelled: dialog.close()
        onSubmitted: {
            dialog.errorText = ""
            dialog.ledger.createAccount(nameField.text, typeBox.currentValue,
                currencyBox.currentText, openingField.text,
                typeBox.currentValue === 2 ? limitField.text : "0")
        }
    }
}
