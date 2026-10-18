import QtQuick
import QtQuick.Layouts
import "../common"
import "../dashboard"

EditorialPage {
    id: page
    title: qsTr("Категории.")
    Item {
        width: parent.width
        height: 80
        EditorialText {
            width: Math.max(0, parent.width - manage.width - 24)
            height: parent.height
            text: qsTr("Доходы и расходы — в отдельных списках.")
            color: "#59616a"
        }
        EditorialAction {
            id: manage
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("+ УПРАВЛЕНИЕ КАТЕГОРИЯМИ")
            onClicked: page.host.editorialManageCategories()
        }
        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: "#031528"
        }
    }
    RowLayout {
        width: parent.width
        spacing: 0
        Repeater {
            model: ["income", "expense"]
            delegate: Item {
                id: group
                required property string modelData
                required property int index
                readonly property var rows: page.controller.categories.filter(function (c) {
                    return c.type === group.modelData;
                })
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: content.height + 48
                Layout.alignment: Qt.AlignTop
                Rectangle {
                    visible: group.index === 1
                    width: 1
                    height: parent.height
                    color: "#031528"
                }
                Column {
                    id: content
                    x: group.index === 1 ? 24 : 0
                    y: 24
                    width: parent.width - 24
                    EditorialSection {
                        width: parent.width
                        number: group.index + 1
                        title: group.index === 0 ? qsTr("Доход") : qsTr("Расход")
                        note: String(group.rows.length)
                    }
                    Repeater {
                        model: group.rows
                        delegate: Item {
                            id: category
                            required property var modelData
                            required property int index
                            width: content.width
                            height: 64
                            EditorialText {
                                width: 32
                                height: parent.height
                                text: String(category.index + 1).padStart(2, "0")
                                font.family: "Cousine"
                                font.pixelSize: 12
                                color: "#59616a"
                            }
                            EditorialText {
                                x: 48
                                width: Math.max(0, parent.width - 80)
                                height: parent.height
                                text: category.modelData.label
                                font.family: "PT Serif"
                                font.pixelSize: page.small ? 20 : 24
                            }
                            EditorialArrow {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                            }
                            Rectangle {
                                y: parent.height - 1
                                width: parent.width
                                height: 1
                                color: "#bbb5a8"
                            }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function (event) {
                                    if (event.button === Qt.RightButton)
                                        page.host.openCategoryContextMenu(category.modelData, mouse, event.x, event.y);
                                    else
                                        page.host.editorialCategoryHistory(category.modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
