import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../computer/common"
import "../computer/common/EditorialStyle.js" as Appearance

ApplicationWindow {
    id: window
    width: 520
    height: 700
    minimumWidth: 320
    minimumHeight: 540
    visible: appAccess.locked
    title: "Vexa"
    palette.window: "#f3eddf"
    palette.base: "#f3eddf"
    palette.button: "#f3eddf"
    palette.text: "#031528"
    palette.windowText: "#031528"
    palette.buttonText: "#031528"
    palette.highlight: "#031528"
    palette.highlightedText: "#f3eddf"
    palette.toolTipBase: "#031528"
    palette.toolTipText: "#f3eddf"
    color: (Appearance.desktop ? "#f3eddf" : "#F5F3E4")
    font.family: "Arimo"
    font.pixelSize: Appearance.desktop ? 16 : 14
    onClosing: Qt.quit()
    property bool recovering: false
    onVisibleChanged: if (visible) { proof.clear(); password.clear(); confirmation.clear(); proof.forceActiveFocus() }

    EditorialScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        EditorialColumnLayout {
            width: Math.min(400, window.width - 48)
            x: (window.width - width) / 2
            y: 40
            spacing: 16
            EditorialLabel { text: "Vexa."; color: "#031528"; font.family: "PT Serif"; font.pixelSize: 48; font.italic: true }
            EditorialDialogTitle {
                Layout.fillWidth: true
                text: appAccess.recoveryCode.length > 0 ? qsTr("Сохраните код восстановления")
                      : window.recovering ? qsTr("Восстановление доступа") : qsTr("Вход в приложение")
                color: "#031528"
                wrapMode: Text.WordWrap
            }
            EditorialLabel {
                visible: appAccess.recoveryCode.length > 0
                Layout.fillWidth: true
                text: qsTr("Код позволит войти и установить новый пароль, если вы забудете текущий. При смене пароля выдаётся новый код.")
                color: (Appearance.desktop ? "#59616a" : "#687483")
                wrapMode: Text.WordWrap
            }
            TextArea {
                visible: appAccess.recoveryCode.length > 0
                Layout.fillWidth: true
                text: appAccess.recoveryCode
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                color: "#031528"
                font.pixelSize: 19
                background: Rectangle { color: (Appearance.desktop ? "#f3eddf" : "#FFFFF8"); radius: Appearance.desktop ? 0 : 12; border.color: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7") }
            }
            StyledCheckBox {
                id: savedCode; objectName: "savedCode"
                Layout.fillWidth: true
                visible: appAccess.recoveryCode.length > 0
                text: qsTr("Я сохранил код восстановления")
            }
            StyledButton {
                visible: appAccess.recoveryCode.length > 0
                Layout.fillWidth: true
                text: qsTr("Продолжить")
                primary: true
                    dimWhenDisabled: false
                enabled: savedCode.checked
                onClicked: { savedCode.checked = false; window.recovering = false; appAccess.acknowledgeRecovery(); proof.forceActiveFocus() }
            }
            EditorialColumnLayout {
                visible: appAccess.ready && appAccess.recoveryCode.length === 0
                Layout.fillWidth: true
                spacing: 16
                StyledTextField {
                    id: proof; objectName: "proof"
                    Layout.fillWidth: true
                    placeholderText: window.recovering ? qsTr("Код восстановления") : qsTr("Пароль")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    enabled: !appAccess.busy
                    onAccepted: if (!window.recovering && !appAccess.busy && !appAccess.retryAfter) { appAccess.unlock(text); clear() }
                }
                StyledTextField {
                    id: password; objectName: "password"
                    visible: window.recovering
                    Layout.fillWidth: true
                    placeholderText: qsTr("Новый пароль: 1–1024 символа")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    enabled: !appAccess.busy
                }
                StyledTextField {
                    id: confirmation; objectName: "confirmation"
                    visible: window.recovering
                    Layout.fillWidth: true
                    placeholderText: qsTr("Повторите новый пароль")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    enabled: !appAccess.busy
                }
                StyledButton {
                    Layout.fillWidth: true
                    text: window.recovering ? qsTr("Установить пароль") : qsTr("Войти")
                    primary: true
                    dimWhenDisabled: false
                    enabled: !appAccess.busy && !appAccess.retryAfter && proof.text.length > 0
                             && (!window.recovering || (password.text.length > 0 && password.text === confirmation.text))
                    onClicked: {
                        if (window.recovering) appAccess.changePassword(proof.text, password.text, confirmation.text)
                        else appAccess.unlock(proof.text)
                        proof.clear(); password.clear(); confirmation.clear()
                    }
                }
                StyledButton {
                    Layout.fillWidth: true
                    flat: true
                    text: window.recovering ? qsTr("Вернуться ко входу") : qsTr("Забыли пароль?")
                    enabled: !appAccess.busy
                    onClicked: { window.recovering = !window.recovering; proof.clear(); password.clear(); confirmation.clear() }
                }
            }
            EditorialLabel {
                visible: appAccess.error.length > 0
                Layout.fillWidth: true
                text: appAccess.error
                color: (Appearance.desktop ? "#b84932" : "#B94F48")
                wrapMode: Text.WordWrap
            }
            EditorialLabel {
                visible: appAccess.retryAfter > 0
                text: qsTr("Повторить через %1 с").arg(appAccess.retryAfter)
                color: (Appearance.desktop ? "#59616a" : "#687483")
            }
            BusyIndicator { running: appAccess.busy; visible: running; Layout.alignment: Qt.AlignHCenter }
            StyledButton {
                visible: !appAccess.busy && appAccess.recoveryCode.length === 0 && (!appAccess.ready || appAccess.error.length > 0)
                Layout.fillWidth: true
                text: qsTr("Повторить")
                onClicked: appAccess.retry()
            }
            Item { Layout.preferredHeight: 40 }
        }
    }
}
