import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: disclosure
    property string title: ""
    property bool expanded: false
    default property alias content: body.data
    implicitHeight: toggle.height + (expanded ? body.implicitHeight + 20 : 0)
    Button {
        id: toggle
        width: parent.width
        height: Math.max(72, label.implicitHeight + 32)
        padding: 0
        Accessible.name: disclosure.title
        Accessible.description: disclosure.expanded ? "Свернуть" : "Развернуть"
        contentItem: RowLayout {
            spacing: 16
            MobileText {
                id: label
                font.family: MobileTheme.serif
                Layout.fillWidth: true
                text: disclosure.title
                font.pixelSize: 24
                wrapMode: Text.Wrap
            }
            MobileText {
                font.family: MobileTheme.serif
                text: disclosure.expanded ? "−" : "+"
                font.pixelSize: 24
            }
        }
        background: Item {
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: MobileTheme.line
            }
        }
        onClicked: disclosure.expanded = !disclosure.expanded
    }
    ColumnLayout {
        id: body
        y: toggle.height + 16
        width: parent.width
        spacing: 16
        visible: disclosure.expanded
    }
}
