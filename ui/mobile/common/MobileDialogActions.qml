import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: actions

    property bool busy: false
    property bool canSubmit: true
    property bool danger: false
    property bool sheetStyle: false
    property color submitColor: danger ? MobileTheme.accent : MobileTheme.ink
    property string submitText: "СОХРАНИТЬ"
    property string errorText: ""
    signal cancelled()
    signal submitted()

    spacing: 8

    MobileFormError {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        text: actions.errorText
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        Layout.bottomMargin: actions.sheetStyle ? 15 : MobileTheme.pagePadding
        spacing: 8

        MobileActionButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            visible: !actions.sheetStyle || actions.danger
            focusPolicy: Qt.TabFocus
            text: actions.sheetStyle ? "Отмена" : "ОТМЕНА"
            cornerRadius: actions.sheetStyle ? 0 : 6
            enabled: !actions.busy
            onClicked: actions.cancelled()
        }

        MobileActionButton {
            id: submitButton

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            focusPolicy: Qt.TabFocus
            text: actions.busy ? (actions.sheetStyle ? "Сохранение…" : "СОХРАНЕНИЕ…")
                : actions.submitText
            outlined: false
            actionColor: actions.submitColor
            cornerRadius: actions.sheetStyle ? 0 : 6
            enabled: !actions.busy && actions.canSubmit

            contentItem: RowLayout {
                MobileEditorialText {
                    Layout.fillWidth: true
                    text: submitButton.text
                    font.family: actions.sheetStyle ? MobileTheme.sans : MobileTheme.mono
                    font.pixelSize: actions.sheetStyle ? 14 : 12
                    font.bold: true
                    color: MobileTheme.sidebar
                    horizontalAlignment: actions.sheetStyle && !actions.danger
                        ? Text.AlignLeft : Text.AlignHCenter
                }

                MobileEditorialText {
                    visible: actions.sheetStyle && !actions.danger
                    text: "✓"
                    font.pixelSize: 18
                    color: MobileTheme.sidebar
                }
            }

            onClicked: {
                if (InputMethod.visible)
                    InputMethod.commit()
                actions.submitted()
            }
        }
    }
}
