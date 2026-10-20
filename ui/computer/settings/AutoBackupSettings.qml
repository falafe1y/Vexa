import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

// Automatic copies every 24 hours (device-local time). Opened from the backup section of the settings page.
Item {
    id: autoBackup
    function openSettings() { settingsDialog.open(); }

    FolderDialog {
        id: folderDialog
        title: qsTr("Папка для автокопий Vexa")
        onAccepted: databaseProtection.chooseAutoBackupFolder(selectedFolder)
    }

    EditorialDialog {
        id: passwordDialog; objectName: "autoBackupPasswordDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(480, parent.width - 32)
        padding: 24
        modal: true
        title: databaseProtection.autoBackupPasswordSet ? qsTr("Сменить пароль автокопий") : qsTr("Пароль автокопий")
        onClosed: { newPassword.clear(); repeatPassword.clear() }
        background: Rectangle { color: (Appearance.desktop ? "#f3eddf" : "#FFFFF8"); radius: Appearance.desktop ? 0 : 12; border.color: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7") }
        contentItem: EditorialDialogForm {
            spacing: 12
            EditorialLabel {
                Layout.fillWidth: true
                text: qsTr("Этим паролем открываются автокопии на любом устройстве. Восстановить забытый пароль нельзя.")
                color: "#031528"; font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap
            }
            StyledTextField {
                id: newPassword
                Layout.fillWidth: true
                placeholderText: qsTr("Пароль: 12–1024 символа")
                echoMode: TextInput.Password
            }
            StyledTextField {
                id: repeatPassword
                Layout.fillWidth: true
                placeholderText: qsTr("Повторите пароль")
                echoMode: TextInput.Password
            }
            EditorialLabel {
                Layout.fillWidth: true
                visible: repeatPassword.text.length > 0 && repeatPassword.text !== newPassword.text
                text: qsTr("Пароли не совпадают.")
                color: "#b03a2e"; wrapMode: Text.WordWrap
            }
            EditorialRowLayout {
                Layout.fillWidth: true
                StyledButton { text: qsTr("Отмена"); onClicked: passwordDialog.close() }
                Item { Layout.fillWidth: true }
                StyledButton {
                    text: qsTr("Сохранить")
                    primary: true
                    enabled: newPassword.text.length > 0 && newPassword.text === repeatPassword.text
                    onClicked: {
                        databaseProtection.setAutoBackupPassword(newPassword.text);
                        // The error stays empty when the password was saved; the dialog then closes
                        if (databaseProtection.autoBackupError.length === 0) passwordDialog.close();
                    }
                }
            }
        }
    }

    EditorialDialog {
        id: settingsDialog; objectName: "autoBackupSettingsDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(520, parent.width - 32)
        padding: 24
        modal: true
        title: qsTr("Автокопии")
        background: Rectangle { color: (Appearance.desktop ? "#f3eddf" : "#FFFFF8"); radius: Appearance.desktop ? 0 : 12; border.color: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7") }
        contentItem: EditorialDialogForm {
            spacing: 16
            EditorialLabel {
                Layout.fillWidth: true
                text: qsTr("Копия .vexabackup раз в 24 часа по местному времени, пока Vexa открыта. Хранятся 7 последних копий, старые удаляются.")
                color: "#031528"; font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap
            }
            EditorialLabel {
                Layout.fillWidth: true
                visible: !databaseProtection.autoBackupSupported
                text: qsTr("Автокопии на этой платформе недоступны.")
                color: "#b03a2e"; wrapMode: Text.WordWrap
            }
            StyledCheckBox {
                id: enabledBox
                text: qsTr("Делать автокопии")
                enabled: databaseProtection.autoBackupSupported
                checked: databaseProtection.autoBackupEnabled
                onClicked: databaseProtection.setAutoBackupEnabled(checked)
            }
            EditorialLabel {
                Layout.fillWidth: true
                text: databaseProtection.autoBackupFolder.length > 0 ? qsTr("Папка выбрана.") : qsTr("Папка не выбрана.")
                color: "#59616a"; wrapMode: Text.WordWrap
            }
            StyledButton {
                text: qsTr("Выбрать папку")
                enabled: databaseProtection.autoBackupSupported && !databaseProtection.busy
                onClicked: folderDialog.open()
            }
            EditorialLabel {
                Layout.fillWidth: true
                text: databaseProtection.autoBackupPasswordSet ? qsTr("Пароль автокопий задан.") : qsTr("Пароль автокопий не задан.")
                color: "#59616a"; wrapMode: Text.WordWrap
            }
            StyledButton {
                text: databaseProtection.autoBackupPasswordSet ? qsTr("Сменить пароль") : qsTr("Задать пароль")
                enabled: databaseProtection.autoBackupSupported
                onClicked: passwordDialog.open()
            }
            EditorialLabel {
                Layout.fillWidth: true
                visible: databaseProtection.autoBackupLast.length > 0
                text: qsTr("Последняя копия: %1").arg(databaseProtection.autoBackupLast)
                color: "#59616a"
            }
            EditorialLabel {
                Layout.fillWidth: true
                visible: databaseProtection.autoBackupError.length > 0
                text: databaseProtection.autoBackupError
                color: "#b03a2e"; wrapMode: Text.WordWrap
            }
            EditorialRowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                StyledButton { text: qsTr("Закрыть"); primary: true; onClicked: settingsDialog.close() }
            }
        }
    }
}
