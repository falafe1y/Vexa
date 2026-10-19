import QtQuick
import QtQuick.Controls

Column {
    id: field
    property string label: ""
    property string placeholder: ""
    property string error: ""
    property alias text: input.text
    property alias validator: input.validator
    property alias inputMethodHints: input.inputMethodHints
    spacing: 4
    MobileText {
        font.family: MobileTheme.mono
        width: field.width
        visible: field.label.length > 0
        text: field.label
        wrapMode: Text.Wrap
        font.pixelSize: 12
        color: MobileTheme.muted
    }
    TextField {
        id: input
        width: field.width
        implicitHeight: 48
        leftPadding: 0
        rightPadding: 0
        font.family: MobileTheme.sans
        font.pixelSize: 16
        color: MobileTheme.accent
        placeholderText: field.placeholder
        placeholderTextColor: MobileTheme.muted
        selectByMouse: true
        background: Item {
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: input.activeFocus ? 2 : 1
                color: field.error.length > 0 ? MobileTheme.red : input.activeFocus ? MobileTheme.accent : MobileTheme.line
            }
        }
    }
    MobileText {
        font.family: MobileTheme.mono
        width: field.width
        visible: field.error.length > 0
        text: field.error
        wrapMode: Text.Wrap
        font.pixelSize: 12
        color: MobileTheme.red
    }
}
