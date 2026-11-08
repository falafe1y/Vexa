import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: dialog

    required property var ledger

    property string errorText: ""

    parent: Overlay.overlay

    width: Math.min(440, parent.width - 40)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    title: "Новая категория"
    modal: true
    focus: true

    closePolicy: ledger.commandPending
                 ? Popup.NoAutoClose
                 : Popup.CloseOnEscape

    onOpened: {
        errorText = ""
        nameField.text = ""
        typeBox.currentIndex = 0
        nameField.forceActiveFocus()
    }

    Connections {
        target: dialog.ledger

        function onCommandFinished(commandName, id) {
            if (dialog.visible && commandName === "createCategory") {
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

            placeholderText: "Например, Продукты"
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
                { text: "Доход", value: 0 },
                { text: "Расход", value: 1 }
            ]
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

                dialog.ledger.createCategory(
                    nameField.text,
                    typeBox.currentValue
                )
            }
        }
    }
}
