import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../computer/common"

// Automatic copies on the phone: every 24 hours by device time while Vexa is open; the 7 newest copies are kept.
Item {
    id: autoBackup
    implicitHeight: column.implicitHeight

    FolderDialog {
        id: folderDialog
        title: qsTr("Папка для автокопий Vexa")
        onAccepted: databaseProtection.chooseAutoBackupFolder(selectedFolder)
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        MobileText {
            font.family: MobileTheme.serif
            Layout.fillWidth: true
            text: qsTr("Автокопии")
            color: MobileTheme.accent
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            text: qsTr("Копия .vexabackup раз в 24 часа по местному времени, пока Vexa открыта. Хранятся 7 последних копий.")
            wrapMode: Text.Wrap
            color: MobileTheme.muted
            font.pixelSize: MobileTheme.sizeCaption
        }
        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: !databaseProtection.autoBackupSupported
            text: qsTr("Автокопии на этой платформе недоступны.")
            wrapMode: Text.Wrap
            color: MobileTheme.red
            font.pixelSize: MobileTheme.sizeCaption
        }
        MobileCheckRow {
            Layout.fillWidth: true
            label: qsTr("Делать автокопии")
            checked: databaseProtection.autoBackupEnabled
            enabled: databaseProtection.autoBackupSupported
            onToggled: function (nowChecked) { databaseProtection.setAutoBackupEnabled(nowChecked) }
        }
        MobileButton {
            Layout.fillWidth: true
            text: databaseProtection.autoBackupFolder.length > 0 ? qsTr("Сменить папку") : qsTr("Выбрать папку")
            enabled: databaseProtection.autoBackupSupported && !databaseProtection.busy
            onClicked: folderDialog.open()
        }
        MobileButton {
            Layout.fillWidth: true
            text: databaseProtection.autoBackupPasswordSet ? qsTr("Сменить пароль автокопий") : qsTr("Задать пароль автокопий")
            enabled: databaseProtection.autoBackupSupported
            onClicked: passwordSheet.open()
        }
        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: databaseProtection.autoBackupLast.length > 0
            text: qsTr("Последняя копия: %1").arg(databaseProtection.autoBackupLast)
            color: MobileTheme.muted
            font.pixelSize: MobileTheme.sizeCaption
        }
        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: databaseProtection.autoBackupError.length > 0
            text: databaseProtection.autoBackupError
            wrapMode: Text.Wrap
            color: MobileTheme.red
            font.pixelSize: MobileTheme.sizeCaption
        }
    }

    MobileSheet {
        id: passwordSheet
        title: qsTr("Пароль автокопий")
        onOpened: { newPassword.clear(); repeatPassword.clear(); newPassword.forceActiveFocus() }

        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            text: qsTr("Этим паролем открываются автокопии на любом устройстве. Восстановить забытый пароль нельзя.")
            wrapMode: Text.Wrap
            color: MobileTheme.muted
            font.pixelSize: MobileTheme.sizeCaption
        }
        StyledTextField {
            id: newPassword
            Layout.fillWidth: true
            controlHeight: 48
            appTextColor: MobileTheme.accent
            appMutedColor: MobileTheme.muted
            appPanelColor: MobileTheme.panel
            appSoftColor: MobileTheme.soft
            appLineColor: MobileTheme.line
            appAccentColor: MobileTheme.navSelected
            appOnAccentColor: MobileTheme.accentText
            placeholderText: qsTr("Пароль: 12–1024 символа")
            echoMode: TextInput.Password
        }
        StyledTextField {
            id: repeatPassword
            Layout.fillWidth: true
            controlHeight: 48
            appTextColor: MobileTheme.accent
            appMutedColor: MobileTheme.muted
            appPanelColor: MobileTheme.panel
            appSoftColor: MobileTheme.soft
            appLineColor: MobileTheme.line
            appAccentColor: MobileTheme.navSelected
            appOnAccentColor: MobileTheme.accentText
            placeholderText: qsTr("Повторите пароль")
            echoMode: TextInput.Password
        }
        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: repeatPassword.text.length > 0 && repeatPassword.text !== newPassword.text
            text: qsTr("Пароли не совпадают.")
            color: MobileTheme.red
            font.pixelSize: MobileTheme.sizeCaption
        }
        MobileButton {
            Layout.fillWidth: true
            variant: "primary"
            text: qsTr("Сохранить пароль")
            enabled: newPassword.text.length > 0 && newPassword.text === repeatPassword.text
            onClicked: {
                databaseProtection.setAutoBackupPassword(newPassword.text);
                // The error stays empty when the password was saved; the sheet then closes
                if (databaseProtection.autoBackupError.length === 0) passwordSheet.close();
            }
        }
    }
}
