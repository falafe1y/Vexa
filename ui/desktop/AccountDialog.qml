import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: dialog

    required property var ledger

    property string errorText: ""

    parent: Overlay.overlay

    width: Math.min(480, parent.width - 40)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    title: "Новый счёт"
    modal: true
    focus: true

    closePolicy: ledger.commandPending
                 ? Popup.NoAutoClose
                 : Popup.CloseOnEscape

    onOpened: {
        errorText = ""
        nameField.text = ""
        typeBox.currentIndex = 0
        currencyBox.currentIndex = 0
        openingField.text = "0"
        limitField.text = "0"
        nameField.forceActiveFocus()
    }

    Connections {
        target: dialog.ledger

        function onCommandFinished(commandName, id) {
            if (dialog.visible && commandName === "createAccount") {
                dialog.close()
            }
        }

        function onErrorOccurred(message) {
            if (dialog.visible) {
                dialog.errorText = message
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        Label {
            text: "Название"
        }

        TextField {
            id: nameField

            Layout.fillWidth: true
            enabled: !dialog.ledger.commandPending

            placeholderText: "Например, Наличные"
        }

        Label {
            text: "Тип"
        }

        ComboBox {
            id: typeBox

            Layout.fillWidth: true
            enabled: !dialog.ledger.commandPending

            textRole: "text"
            valueRole: "value"

            model: [
                { text: "Наличные", value: 0 },
                { text: "Дебетовая карта", value: 1 },
                { text: "Кредитная карта", value: 2 }
            ]
        }

        Label {
            text: "Валюта"
        }

        ComboBox {
            id: currencyBox

            Layout.fillWidth: true
            enabled: !dialog.ledger.commandPending

            model: ["RUB", "USD", "EUR", "CNY"]
        }

        Label {
            text: "Начальный остаток"
        }

        TextField {
            id: openingField

            Layout.fillWidth: true
            enabled: !dialog.ledger.commandPending

            placeholderText: "0,00"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }

        Label {
            Layout.fillWidth: true

            visible: typeBox.currentValue === 2
            wrapMode: Text.Wrap

            text: "Если уже есть долг 60 000, укажите остаток -60000."
        }

        Label {
            visible: typeBox.currentValue === 2
            text: "Кредитный лимит"
        }

        TextField {
            id: limitField

            Layout.fillWidth: true

            visible: typeBox.currentValue === 2
            enabled: !dialog.ledger.commandPending

            placeholderText: "Например, 90000"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }

        Label {
            Layout.fillWidth: true

            visible: dialog.errorText.length > 0
            text: dialog.errorText
            color: "#c62828"
            wrapMode: Text.Wrap
        }
    }

    footer: RowLayout {
        spacing: 8

        Item {
            Layout.fillWidth: true
        }

        Button {
            text: "Отмена"
            enabled: !dialog.ledger.commandPending

            onClicked: dialog.close()
        }

        Button {
            text: dialog.ledger.commandPending
                  ? "Сохранение…"
                  : "Создать"

            enabled: !dialog.ledger.commandPending
                     && nameField.text.trim().length > 0

            onClicked: {
                dialog.errorText = ""

                dialog.ledger.createAccount(
                    nameField.text,
                    typeBox.currentValue,
                    currencyBox.currentText,
                    openingField.text,
                    typeBox.currentValue === 2
                        ? limitField.text
                        : "0"
                )
            }
        }
    }
}
