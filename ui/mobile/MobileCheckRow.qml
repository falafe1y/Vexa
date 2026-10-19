import QtQuick

Item {
    id: row

    property string label: ""
    property bool checked: false
    signal toggled(bool nowChecked)

    implicitWidth: 200
    implicitHeight: Math.max(48, labelText.implicitHeight + 16)

    Rectangle {
        id: box

        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 0
        color: row.checked ? MobileTheme.accent : MobileTheme.panel
        border.width: 1
        border.color: row.checked ? MobileTheme.accent : MobileTheme.accentSoft

        MobileIcon {
            anchors.centerIn: parent
            visible: row.checked
            name: "check"
            width: 16
            height: 16
            color: MobileTheme.accentText
        }
    }

    MobileText {
        id: labelText
        font.family: MobileTheme.sans
        anchors.left: box.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        wrapMode: Text.Wrap
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeBody
    }

    TapHandler {
        onTapped: {
            row.checked = !row.checked;
            row.toggled(row.checked);
        }
    }
}
