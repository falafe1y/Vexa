pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)

    spacing: 0

    component CategoryList: ColumnLayout {
        id: column

        required property string heading
        required property color headingColor
        required property var categoriesModel

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 1
        spacing: 0

        MobileEditorialText {
            Layout.fillWidth: true
            topPadding: 16
            bottomPadding: 9
            text: column.heading
            color: column.headingColor
            font.family: MobileTheme.mono
            font.pixelSize: 13
            Accessible.role: Accessible.Heading
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: MobileTheme.line
        }

        ListView {
            id: categories

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            model: column.categoriesModel

            Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

            delegate: Basic.ItemDelegate {
                id: category

                required property var model

                width: ListView.view.width
                implicitHeight: Math.max(44, implicitContentHeight + topPadding + bottomPadding)
                padding: 0
                topPadding: 8
                bottomPadding: 8
                text: model.name
                enabled: !page.ledger.commandPending

                contentItem: MobileEditorialText {
                    text: category.text
                    font.pixelSize: 16
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                background: Rectangle {
                    color: category.down ? MobileTheme.sidebar : "transparent"
                    border.width: category.visualFocus ? 1 : 0
                    border.color: MobileTheme.accent

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: MobileTheme.line
                    }
                }

                onClicked: categoryMenu.open()
                onPressAndHold: categoryMenu.open()

                MobileContextActionMenu {
                    id: categoryMenu

                    onEditRequested: page.editRequested({
                        id: category.model.id,
                        name: category.model.name,
                        type: category.model.type
                    })
                    onRemoveRequested: page.removeRequested(category.model.id, category.model.name)
                }
            }

            MobileEditorialText {
                anchors.top: parent.top
                anchors.topMargin: 10
                width: parent.width
                visible: page.ledger.ready && categories.count === 0
                text: "Пока нет категорий"
                color: MobileTheme.muted
                wrapMode: Text.WordWrap
            }
        }
    }

    MobilePageHeading {
        Layout.fillWidth: true
        Layout.topMargin: 13
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        documentStyle: true
        text: "Категории"
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        spacing: 14

        CategoryList {
            heading: "Расходы"
            headingColor: MobileTheme.historyExpense
            categoriesModel: page.ledger.expenseCategoriesModel
        }

        CategoryList {
            heading: "Доходы"
            headingColor: MobileTheme.historyIncome
            categoriesModel: page.ledger.incomeCategoriesModel
        }
    }
}
