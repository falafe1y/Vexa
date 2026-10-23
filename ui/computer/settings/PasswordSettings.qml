import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

EditorialColumnLayout {
    id: settings
    function openEditor(removing) { dialog.removing = removing; dialog.open(); }
    spacing: 16
    EditorialLabel { text: "Защита паролем"; color: "#031528"; font.pixelSize: 17; font.bold: true }
    EditorialLabel {
        Layout.fillWidth: true
        text: appAccess.enabled ? "Пароль включён. Автоблокировка через 10 минут бездействия."
                                : "Пароль необязателен. Можно использовать от 1 до 1024 символов."
        color: (Appearance.desktop ? "#59616a" : "#687483")
        wrapMode: Text.WordWrap
    }
    EditorialLabel {
        visible: !appAccess.storeAvailable
        Layout.fillWidth: true
        text: !appAccess.storeChecked ? "Проверяем системное хранилище…"
              : (appAccess.storeError || "Системное хранилище недоступно. Защита паролем недоступна.")
        color: (Appearance.desktop ? "#59616a" : "#687483")
        wrapMode: Text.WordWrap
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        StyledButton {
            text: appAccess.enabled ? "Изменить пароль" : "Установить пароль"
            enabled: appAccess.storeChecked && appAccess.storeAvailable && appAccess.ready && !appAccess.busy
            onClicked: { dialog.removing = false; dialog.open() }
        }
        StyledButton {
            visible: appAccess.enabled
            text: "Отключить пароль"
            enabled: appAccess.storeChecked && appAccess.storeAvailable && appAccess.ready && !appAccess.busy
            onClicked: { dialog.removing = true; dialog.open() }
        }
        StyledButton {
            visible: appAccess.enabled
            text: "Заблокировать"
            onClicked: appAccess.lock()
        }
    }
    EditorialDialog {
        id: dialog; objectName: "dialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 32)
        modal: true
        property bool removing: false
        title: removing ? "Отключить пароль" : appAccess.enabled ? "Изменить пароль" : "Установить пароль"
        padding: 24
        background: Rectangle { color: (Appearance.desktop ? "#f3eddf" : "#FFFFF8"); radius: Appearance.desktop ? 0 : 12; border.color: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7") }
        onOpened: { current.clear(); password.clear(); confirmation.clear(); current.visible ? current.forceActiveFocus() : password.forceActiveFocus() }
        onClosed: { current.clear(); password.clear(); confirmation.clear() }
        contentItem: EditorialDialogForm {
            spacing: 16
            StyledTextField {
                id: current; objectName: "current"
                visible: appAccess.enabled
                Layout.fillWidth: true
                placeholderText: "Текущий пароль или код восстановления"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            }
            StyledTextField {
                id: password; objectName: "password"
                visible: !dialog.removing
                Layout.fillWidth: true
                placeholderText: "Новый пароль: 1–1024 символа"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            }
            StyledTextField {
                id: confirmation; objectName: "confirmation"
                visible: !dialog.removing
                Layout.fillWidth: true
                placeholderText: "Повторите пароль"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            }
            EditorialLabel {
                visible: appAccess.error.length > 0
                Layout.fillWidth: true
                text: appAccess.error
                color: (Appearance.desktop ? "#b84932" : "#B94F48")
                wrapMode: Text.WordWrap
            }
            EditorialRowLayout {
                Layout.fillWidth: true
                StyledButton { text: "Отмена"; onClicked: dialog.close() }
                Item { Layout.fillWidth: true }
                StyledButton {
                    text: dialog.removing ? "Отключить" : "Сохранить"
                    primary: true
                    dimWhenDisabled: false
                    enabled: appAccess.storeAvailable && !appAccess.busy && (!appAccess.enabled || current.text.length > 0)
                             && (dialog.removing || (password.text.length > 0 && password.text === confirmation.text))
                    onClicked: {
                        if (dialog.removing) appAccess.disablePassword(current.text)
                        else appAccess.changePassword(current.text, password.text, confirmation.text)
                        current.clear(); password.clear(); confirmation.clear()
                    }
                }
            }
        }
    }
}
