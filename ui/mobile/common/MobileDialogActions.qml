import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: actions

    property bool busy: false
    property bool canSubmit: true
    property bool danger: false
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
        Layout.bottomMargin: MobileTheme.pagePadding
        spacing: 8

        MobileActionButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            focusPolicy: Qt.TabFocus
            text: "ОТМЕНА"
            enabled: !actions.busy
            onClicked: actions.cancelled()
        }

        MobileActionButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            focusPolicy: Qt.TabFocus
            text: actions.busy ? "СОХРАНЕНИЕ…" : actions.submitText
            outlined: false
            danger: actions.danger
            enabled: !actions.busy && actions.canSubmit
            onClicked: {
                if (InputMethod.visible)
                    InputMethod.commit()
                actions.submitted()
            }
        }
    }
}
