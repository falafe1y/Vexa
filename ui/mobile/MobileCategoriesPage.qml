import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: page
    required property var host
    property string categoryType: "expense"
    spacing: 16
    function create() {
        host.createCategory(categoryType);
    }
    MobileSegmented {
        Layout.fillWidth: true
        options: [
            {
                label: "Расходы",
                value: "expense"
            },
            {
                label: "Доходы",
                value: "income"
            }
        ]
        value: page.categoryType
        onActivated: function (chosen) {
            page.categoryType = chosen;
        }
    }
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        pixelAligned: true
        model: financeController.categories.filter(function (row) {
            return row.type === page.categoryType;
        })
        delegate: Item {
            required property var modelData
            width: list.width
            height: 72
            RowLayout {
                anchors.fill: parent
                spacing: 12
                MobileText {
                    font.family: MobileTheme.serif
                    Layout.fillWidth: true
                    text: modelData.label || modelData.name
                    font.pixelSize: 24
                    elide: Text.ElideRight
                }
                MobileIconButton {
                    id: categoryMenuButton
                    icon: "more"
                    onClicked: page.host.editCategory(modelData)
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: MobileTheme.line
            }
            TapHandler {
                onTapped: {
                    const local = categoryMenuButton.mapFromItem(parent, point.position.x, point.position.y);
                    if (categoryMenuButton.contains(local))
                        return;
                    page.host.historyCategory = modelData.label || modelData.name;
                    page.host.openTab("overview");
                }
                onLongPressed: page.host.editCategory(modelData)
            }
        }
        MobileText {
            font.family: MobileTheme.mono
            anchors.centerIn: parent
            visible: list.count === 0
            text: "Категорий пока нет"
            font.pixelSize: 12
            color: MobileTheme.muted
        }
    }
}
