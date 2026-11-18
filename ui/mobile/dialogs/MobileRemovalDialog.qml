import QtQuick
import QtQuick.Layouts

MobileFormDialog {
    id: dialog

    required property var ledger

    property string commandName: ""
    property string recordId: ""
    property string description: ""

    readonly property bool removingOperation:
        commandName === "removeOperation"

    readonly property bool removingCategory:
        commandName === "removeCategory"

    title: removingOperation
        ? "Удалить операцию?"
        : removingCategory
            ? "Удалить категорию?"
            : "Удалить счёт?"

    busy: ledger.commandPending

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
        width: parent.width
        spacing: 20

        MobileEditorialText {
            Layout.fillWidth: true
            visible: text.length > 0
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            text: dialog.description
        }
    }

    footer: MobileDialogActions {
        errorText: dialog.errorText
        busy: dialog.busy
        sheetStyle: dialog.sheetStyle
        submitText: dialog.sheetStyle ? "Удалить" : "УДАЛИТЬ"
        danger: true

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
