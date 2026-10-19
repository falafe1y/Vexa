import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: bar
    property var items: []
    property string activeKey: "overview"
    property string centerKey: "add"
    signal selected(string key)
    readonly property real safeBottom: SafeArea.margins.bottom
    implicitHeight: 72 + safeBottom
    color: MobileTheme.canvas
    Rectangle {
        width: parent.width
        height: 1
        color: MobileTheme.accent
    }
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        height: 72
        spacing: 0
        Repeater {
            model: bar.items
            delegate: Button {
                id: tab
                required property var modelData
                readonly property bool central: modelData.key === bar.centerKey
                readonly property bool current: modelData.key === bar.activeKey
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                enabled: !modelData.disabled
                padding: 0
                Accessible.name: modelData.title
                background: Item {
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 32
                        height: 2
                        visible: tab.current
                        color: MobileTheme.accent
                    }
                }
                contentItem: Item {
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: tab.central ? 12 : 8
                        width: tab.central ? 48 : 28
                        height: tab.central ? 48 : 28
                        color: tab.central ? (tab.enabled ? MobileTheme.accent : MobileTheme.line) : "transparent"
                        MobileIcon {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            name: tab.modelData.icon
                            color: tab.central ? MobileTheme.canvas : tab.current ? MobileTheme.copper : MobileTheme.accent
                        }
                    }
                    MobileText {
                        visible: !tab.central
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        width: parent.width
                        text: tab.modelData.title
                        font.pixelSize: 12
                        font.family: MobileTheme.sans
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
                onClicked: bar.selected(modelData.key)
            }
        }
    }
}
