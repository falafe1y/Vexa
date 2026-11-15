pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger
    property int currentType: 0
    signal createRequested(int type)
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)

    spacing: 12

    MobilePageHeading {
        Layout.fillWidth: true
        Layout.topMargin: 14
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        text: "Категории."
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        spacing: 8

        Repeater {
            model: ["ДОХОДЫ", "РАСХОДЫ"]

            delegate: MobileActionButton {
                id: typeButton

                required property int index
                required property string modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: typeButton.modelData
                outlined: page.currentType !== typeButton.index
                Accessible.role: Accessible.PageTab
                Accessible.selected: page.currentType === typeButton.index
                onClicked: page.currentType = typeButton.index
            }
        }
    }

    ListView {
        id: categories

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        clip: true
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        model: page.currentType === 0 ? page.ledger.incomeCategoriesModel : page.ledger.expenseCategoriesModel

        Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

        delegate: Item {
            id: category

            required property var model

            width: ListView.view.width
            height: 56

            RowLayout {
                anchors.fill: parent
                spacing: 8

                MobileEditorialText {
                    Layout.fillWidth: true
                    text: category.model.name
                    font.pixelSize: 16
                }

                MobileActionButton {
                    flat: true
                    text: "⋯"
                    font.pixelSize: 21
                    enabled: !page.ledger.commandPending
                    Accessible.name: "Действия с категорией " + category.model.name
                    onClicked: categoryMenu.open()

                    MobileContextActionMenu {
                        id: categoryMenu

                        editEnabled: !page.ledger.commandPending
                        removeEnabled: !page.ledger.commandPending
                        onEditRequested: page.editRequested({
                            id: category.model.id,
                            name: category.model.name,
                            type: category.model.type
                        })
                        onRemoveRequested: page.removeRequested(category.model.id, category.model.name)
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: MobileTheme.line
            }
        }

        MobileEditorialText {
            anchors.top: parent.top
            anchors.topMargin: 10
            width: parent.width
            visible: page.ledger.ready && categories.count === 0
            text: page.currentType === 0 ? "Категорий доходов пока нет." : "Категорий расходов пока нет."
            color: MobileTheme.muted
            wrapMode: Text.WordWrap
        }
    }

    MobileActionButton {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        Layout.bottomMargin: 8
        text: "+ НОВАЯ КАТЕГОРИЯ"
        outlined: false
        enabled: page.ledger.ready && !page.ledger.commandPending
        onClicked: page.createRequested(page.currentType)
    }
}
