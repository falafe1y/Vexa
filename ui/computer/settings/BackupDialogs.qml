import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

Item {
    id: flow
    readonly property bool active: exportDialog.visible || importDialog.visible || saveFile.visible || openFile.visible
    property string localError: ""
    property bool recoveryMode: false
    // On Android the app is not restarted by itself: the user closes it and opens it again.
    readonly property string restartNote: Qt.platform.os === "android"
        ? "Нужен перезапуск: закройте Vexa и откройте её снова." : "Vexa перезапустится."
    signal exported(string path)
    function openExport() {
        if (databaseProtection.busy) return
        databaseProtection.discardBackup()
        localError = ""
        plaintext.checked = false
        exportPassword.clear(); repeatPassword.clear()
        exportDialog.open()
    }
    function openImport() {
        if (databaseProtection.busy) return
        databaseProtection.discardBackup()
        localError = ""
        importPassword.clear()
        openFile.open()
    }
    function flushNotes() {
        if (recoveryMode) return true
        if (financeController.saveNotes()) return true
        localError = financeController.notesError
        return false
    }
    Connections {
        target: databaseProtection
        function onBackupExported(path) { exportDialog.close(); flow.exported(path) }
    }
    FileDialog {
        id: saveFile
        title: "Сохранить резервную копию Vexa"
        fileMode: FileDialog.SaveFile
        nameFilters: plaintext.checked ? ["Открытая база (*.sqlite3)"] : ["Защищённая копия Vexa (*.vexabackup)"]
        defaultSuffix: plaintext.checked ? "sqlite3" : "vexabackup"
        onAccepted: {
            if (!flow.flushNotes()) return
            databaseProtection.exportBackup(selectedFile, exportPassword.text, plaintext.checked)
            exportPassword.clear(); repeatPassword.clear()
        }
    }
    FileDialog {
        id: openFile
        title: "Выберите резервную копию Vexa"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Копии Vexa (*.vexabackup *.sqlite3 *.db)", "Все файлы (*)"]
        onAccepted: {
            databaseProtection.inspectBackup(selectedFile, "")
            importDialog.open()
        }
    }
    EditorialDialog {
        id: exportDialog; objectName: "exportDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(520, parent.width - 48)
        padding: 24
        modal: true
        closePolicy: databaseProtection.busy ? Popup.NoAutoClose : Popup.CloseOnEscape
        title: "Создать резервную копию"
        onClosed: { exportPassword.clear(); repeatPassword.clear(); databaseProtection.discardBackup() }
        background: Rectangle { color: (Appearance.desktop ? "#f3eddf" : "#FFFFF8"); radius: Appearance.desktop ? 0 : 16; border.color: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7") }
        contentItem: EditorialDialogForm {
            spacing: 16
            EditorialLabel {
                Layout.fillWidth: true
                text: "Пароль позволит восстановить данные на другом устройстве или после переустановки системы. Сохраните его: восстановить забытый пароль копии невозможно."
                color: "#031528"; font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap
            }
            StyledCheckBox {
                id: plaintext; objectName: "plaintext"
                text: "Сохранить без пароля"
                enabled: !databaseProtection.busy
            }
            EditorialLabel {
                Layout.fillWidth: true
                visible: plaintext.checked
                text: "Файл будет содержать открытые данные, даже если локальная база зашифрована."
                color: (Appearance.desktop ? "#b84932" : "#B94F48"); font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap
            }
            StyledTextField {
                id: exportPassword; objectName: "exportPassword"
                Layout.fillWidth: true
                visible: !plaintext.checked
                enabled: !databaseProtection.busy
                echoMode: TextInput.Password
                maximumLength: 2048
                placeholderText: "Пароль копии: 12–1024 символа"
            }
            StyledTextField {
                id: repeatPassword; objectName: "repeatPassword"
                Layout.fillWidth: true
                visible: !plaintext.checked
                enabled: !databaseProtection.busy
                echoMode: TextInput.Password
                maximumLength: 2048
                placeholderText: "Повторите пароль"
            }
            EditorialLabel {
                Layout.fillWidth: true
                text: flow.localError || databaseProtection.backupError
                visible: text.length > 0
                color: (Appearance.desktop ? "#b84932" : "#B94F48"); font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap
            }
            BusyIndicator { running: databaseProtection.busy; visible: running; Layout.alignment: Qt.AlignHCenter }
            EditorialRowLayout {
                Layout.fillWidth: true
                StyledButton { text: "Отмена"; enabled: !databaseProtection.busy; onClicked: exportDialog.close() }
                Item { Layout.fillWidth: true }
                StyledButton {
                    text: "Сохранить"
                    primary: true
                    enabled: !databaseProtection.busy
                    onClicked: {
                        flow.localError = ""
                        if (!plaintext.checked) {
                            const count = Array.from(exportPassword.text).length
                            if (count < 12 || count > 1024) { flow.localError = "Пароль копии должен содержать от 12 до 1024 символов."; return }
                            if (exportPassword.text !== repeatPassword.text) { flow.localError = "Пароли не совпадают."; return }
                        }
                        saveFile.open()
                    }
                }
            }
        }
    }
    EditorialDialog {
        id: importDialog; objectName: "importDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(520, parent.width - 48)
        padding: 24
        modal: true
        closePolicy: databaseProtection.busy ? Popup.NoAutoClose : Popup.CloseOnEscape
        title: databaseProtection.hasBackupPreview ? "Восстановить данные из копии?" : "Проверка резервной копии"
        onClosed: { importPassword.clear(); databaseProtection.discardBackup() }
        background: Rectangle { color: (Appearance.desktop ? "#f3eddf" : "#FFFFF8"); radius: Appearance.desktop ? 0 : 16; border.color: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7") }
        contentItem: EditorialDialogForm {
            spacing: 16
            EditorialLabel {
                Layout.fillWidth: true
                text: databaseProtection.sourceName(openFile.selectedFile)
                color: (Appearance.desktop ? "#59616a" : "#687483"); font.pixelSize: Appearance.desktop ? 16 : 14; elide: Text.ElideMiddle
            }
            StyledTextField {
                id: importPassword; objectName: "importPassword"
                Layout.fillWidth: true
                visible: databaseProtection.backupPasswordRequired && !databaseProtection.hasBackupPreview
                enabled: !databaseProtection.busy
                echoMode: TextInput.Password
                maximumLength: 2048
                placeholderText: "Пароль резервной копии"
            }
            EditorialLabel {
                Layout.fillWidth: true
                visible: databaseProtection.hasBackupPreview
                text: {
                    const summary = databaseProtection.backupSummary
                    let details = "Счетов: %1 · Операций: %2".arg(summary.accountCount || 0).arg(summary.activityCount || 0)
                    if (summary.createdAt) details += "\n" + "Создана: %1".arg(Qt.formatDateTime(new Date(summary.createdAt), "dd.MM.yyyy HH:mm"))
                    if (summary.appVersion) details += "\n" + "Версия Vexa: %1".arg(summary.appVersion)
                    return details
                }
                color: "#031528"; font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap
            }
            EditorialLabel {
                Layout.fillWidth: true
                visible: databaseProtection.hasBackupPreview
                text: flow.recoveryMode
                    ? "Недоступная база будет заменена данными из копии. Исходные файлы сохраним отдельно. Если прежняя база была зашифрована, восстановленная база также будет зашифрована системным ключом. %1".arg(flow.restartNote)
                    : "Текущие счета, операции, настройки и заметки будут заменены. Перед заменой сохраним копию текущего состояния. Настройка шифрования этой установки сохранится. %1".arg(flow.restartNote)
                color: "#031528"; font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap
            }
            EditorialLabel {
                Layout.fillWidth: true
                text: flow.localError || databaseProtection.backupError
                visible: text.length > 0
                color: (Appearance.desktop ? "#b84932" : "#B94F48"); font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap
            }
            BusyIndicator { running: databaseProtection.busy; visible: running; Layout.alignment: Qt.AlignHCenter }
            EditorialRowLayout {
                Layout.fillWidth: true
                StyledButton { text: "Отмена"; enabled: !databaseProtection.busy; onClicked: importDialog.close() }
                Item { Layout.fillWidth: true }
                StyledButton {
                    text: databaseProtection.hasBackupPreview ? "Восстановить" : "Проверить"
                    primary: true
                    enabled: !databaseProtection.busy
                    onClicked: {
                        flow.localError = ""
                        if (databaseProtection.hasBackupPreview) {
                            if (flow.flushNotes()) databaseProtection.restoreBackup()
                        } else {
                            databaseProtection.inspectBackup(openFile.selectedFile, importPassword.text)
                            importPassword.clear()
                        }
                    }
                }
            }
        }
    }
}
