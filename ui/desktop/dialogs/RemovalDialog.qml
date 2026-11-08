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
    title: commandName === "removeOperation" ? "Удалить операцию?" : "Убрать запись?"
    closePolicy: ledger.commandPending ? Popup.NoAutoClose : Popup.CloseOnEscape

    function ask(command, recordId, description) {
        commandName = command
        dialog.recordId = recordId
        dialog.description = description
        errorText = ""
        open()
    }

    Connections {
        target: dialog.ledger
        function onCommandFinished(commandName, id) {
            if (dialog.visible && commandName === dialog.commandName) dialog.close()
        }
        function onErrorOccurred(message) {
            if (dialog.visible) dialog.errorText = message
        }
    }

    body: ColumnLayout {
        width: dialog.availableWidth
        spacing: 16
        EditorialText {
            Layout.fillWidth: true
            text: dialog.description
            font.bold: true
            wrapMode: Text.WordWrap
        }
        EditorialText {
            Layout.fillWidth: true
            text: dialog.commandName === "removeOperation"
                  ? "Операция будет удалена, а остатки счетов пересчитаны."
                  : "Использованная запись уйдёт в архив. Неиспользованная будет удалена. История сохранится."
            color: DesktopTheme.muted
            wrapMode: Text.WordWrap
        }
        FormError { Layout.fillWidth: true; message: dialog.errorText }
    }

    footer: DialogActions {
        busy: dialog.ledger.commandPending
        submitText: "ПОДТВЕРДИТЬ"
        onCancelled: dialog.close()
        onSubmitted: {
            dialog.errorText = ""
            if (dialog.commandName === "removeAccount") dialog.ledger.removeAccount(dialog.recordId)
            else if (dialog.commandName === "removeCategory") dialog.ledger.removeCategory(dialog.recordId)
            else dialog.ledger.removeOperation(dialog.recordId)
        }
    }
}
