import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

EditorialColumnLayout {
    function openConfirmation() { confirmation.open(); }
    spacing: 16
    EditorialLabel { text: qsTr("Шифрование базы"); color: "#031528"; font.pixelSize: 17; font.bold: true }
    EditorialLabel {
        Layout.fillWidth: true
        text: databaseProtection.encrypted
            ? qsTr("Локальная база зашифрована. Ключ хранится в учётной записи Windows.")
            : qsTr("Шифрование защищает файл базы. Оно независимо от пароля входа в Vexa.")
        color: (Appearance.desktop ? "#59616a" : "#687483")
        wrapMode: Text.WordWrap
    }
    EditorialLabel {
        visible: !appAccess.storeAvailable || !databaseProtection.supported
        Layout.fillWidth: true
        text: (!appAccess.storeAvailable
               ? (!appAccess.storeChecked ? qsTr("Проверяем системное хранилище…")
                  : (appAccess.storeError || qsTr("Системное хранилище недоступно."))) : "")
              + ((!appAccess.storeAvailable && !databaseProtection.supported) ? "\n" : "")
              + (!databaseProtection.supported ? qsTr("Шифрование базы на этой платформе пока не поддерживается.") : "")
        color: (Appearance.desktop ? "#59616a" : "#687483")
        wrapMode: Text.WordWrap
    }
    StyledButton {
        text: databaseProtection.encrypted ? qsTr("Отключить шифрование") : qsTr("Включить шифрование")
        enabled: databaseProtection.supported && appAccess.storeChecked && appAccess.storeAvailable && databaseProtection.ready && !databaseProtection.busy
        onClicked: confirmation.open()
    }
    EditorialDialog {
        id: confirmation; objectName: "confirmation"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(480, parent.width - 32)
        padding: 24
        modal: true
        title: databaseProtection.encrypted ? qsTr("Отключить шифрование базы?") : qsTr("Зашифровать базу?")
        background: Rectangle { color: (Appearance.desktop ? "#f3eddf" : "#FFFFF8"); radius: Appearance.desktop ? 0 : 12; border.color: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7") }
        contentItem: EditorialDialogForm {
            spacing: 16
            EditorialLabel {
                Layout.fillWidth: true
                text: databaseProtection.encrypted
                    ? qsTr("После отключения файл базы будет доступен без ключа. Ключ сохранится для чтения ранее зашифрованных копий. Vexa перезапустится.")
                    : qsTr("База будет зашифрована ключом из системного хранилища Windows. Для её открытия потребуется этот ключ. Старые копии останутся без изменений. Vexa перезапустится.")
                color: "#031528"
                font.pixelSize: Appearance.desktop ? 16 : 14
                wrapMode: Text.WordWrap
            }
            EditorialRowLayout {
                Layout.fillWidth: true
                StyledButton { text: qsTr("Отмена"); onClicked: confirmation.close() }
                Item { Layout.fillWidth: true }
                StyledButton {
                    text: qsTr("Продолжить")
                    primary: true
                    enabled: databaseProtection.supported && appAccess.storeAvailable && databaseProtection.ready && !databaseProtection.busy
                    onClicked: { confirmation.close(); databaseProtection.requestChange(!databaseProtection.encrypted) }
                }
            }
        }
    }
}
