
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

FormDialog {
    id: dialog

    required property var ledger

    property string commandName: ""
    property string recordId: ""
    property string description: ""
    property string errorText: ""

    readonly property bool removingOperation:
        commandName === "removeOperation"

    readonly property bool removingCategory:
        commandName === "removeCategory"

    title: removingOperation
        ? "Удалить операцию?"
        : removingCategory
            ? "Удалить категорию?"
            : "Удалить счет?"

    closePolicy: ledger.commandPending
        ? Popup.NoAutoClose
        : Popup.CloseOnEscape

    function ask(command, recordId, description) {
        dialog.commandName = command
        dialog.recordId = recordId
        dialog.description = description
        dialog.errorText = ""
        dialog.open()
    }

    Connections {
        target: dialog.ledger

        function onCommandFinished(commandName, id) {
            if (dialog.visible && commandName === dialog.commandName)
                dialog.close()
        }

        function onErrorOccurred(message) {
            if (dialog.visible)
                dialog.errorText = message
        }
    }

    body: ColumnLayout {
        width: dialog.availableWidth
        spacing: 20

        // Текст отображается только для счетов и категорий
        EditorialText {
            Layout.fillWidth: true

            visible: !dialog.removingOperation

            textFormat: Text.RichText
            wrapMode: Text.WordWrap

            text: {
                const name = dialog.description
                    .replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
                    .replace(/"/g, "&quot;")

                if (dialog.removingCategory)
                    return "Категория <b>" + name + "</b> будет удалена."

                return "Счет <b>" + name + "</b> будет удален."
            }
        }

        FormError {
            Layout.fillWidth: true
            message: dialog.errorText
        }
    }

    footer: DialogActions {
        busy: dialog.ledger.commandPending
        submitText: "ПОДТВЕРДИТЬ"

        onCancelled: dialog.close()

        onSubmitted: {
            dialog.errorText = ""

            if (dialog.commandName === "removeAccount")
                dialog.ledger.removeAccount(dialog.recordId)
            else if (dialog.commandName === "removeCategory")
                dialog.ledger.removeCategory(dialog.recordId)
            else
                dialog.ledger.removeOperation(dialog.recordId)
        }
    }
}
