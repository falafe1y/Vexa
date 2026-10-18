import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../computer/common"
import "../computer/settings"
import "../computer/common/EditorialStyle.js" as Appearance

ApplicationWindow {
    width: 560
    height: 440
    minimumWidth: 320
    minimumHeight: 340
    visible: !appAccess.locked && !databaseProtection.ready
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
    BackupDialogs {
        id: recoveryDialogs
        recoveryMode: true
    }
    font.family: "Arimo"
    onClosing: function (event) {
        if (databaseProtection.busy)
            event.accepted = false
        else
            Qt.quit()
    }
    EditorialScrollView {
        id: databaseScroll
        anchors.fill: parent
        contentWidth: availableWidth
        contentHeight: databaseContent.implicitHeight + 64
        EditorialColumnLayout {
            id: databaseContent
            x: 32
            y: 32
            width: Math.max(0, databaseScroll.availableWidth - 64)
            spacing: 16
            EditorialLabel {
                text: "Vexa."
                color: "#031528"
                font.family: "PT Serif"
                font.pixelSize: 48
                font.italic: true
            }
            EditorialDialogTitle {
                Layout.fillWidth: true
                text: databaseProtection.busy ? qsTr("Подготовка базы…") : databaseProtection.restartRequired ? qsTr("Требуется перезапуск") : qsTr("Не удалось открыть базу")
                color: "#031528"
                wrapMode: Text.WordWrap
            }
            BusyIndicator {
                visible: databaseProtection.busy
                running: visible
                Layout.alignment: Qt.AlignHCenter
            }
            EditorialScrollView {
                visible: databaseProtection.error.length > 0
                Layout.fillWidth: true
                Layout.maximumHeight: 140
                implicitHeight: errorText.implicitHeight
                contentWidth: availableWidth
                TextArea {
                    id: errorText
                    objectName: "errorText"
                    text: databaseProtection.error
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: (Appearance.desktop ? "#b84932" : "#B94F48")
                    font.pixelSize: Appearance.desktop ? 16 : 14
                    background: null
                }
            }
            StyledButton {
                visible: !databaseProtection.busy && !databaseProtection.restartRequired && databaseProtection.error.length > 0
                text: qsTr("Восстановить из копии")
                onClicked: recoveryDialogs.openImport()
            }
            StyledButton {
                visible: !databaseProtection.busy
                text: databaseProtection.restartRequired ? qsTr("Перезапустить") : qsTr("Повторить")
                onClicked: databaseProtection.restartRequired ? databaseProtection.restart() : databaseProtection.prepare()
            }
        }
    }
}
