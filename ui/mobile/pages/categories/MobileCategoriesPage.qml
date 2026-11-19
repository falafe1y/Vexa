pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger
    signal historyRequested(string categoryId)
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

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 19
            Layout.bottomMargin: 10
            spacing: 8

            MobileEditorialText {
                Layout.fillWidth: true
                text: column.heading
                color: column.headingColor
                font.family: MobileTheme.mono
                font.pixelSize: 13
                Accessible.role: Accessible.Heading
            }

            MobileEditorialText {
                text: column.categoriesModel.count
                font.family: MobileTheme.mono
                font.pixelSize: 11
                color: MobileTheme.muted
            }
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
                implicitHeight: Math.max(69, implicitContentHeight + topPadding + bottomPadding)
                padding: 0
                topPadding: 12
                bottomPadding: 12
                text: model.name
                enabled: !page.ledger.commandPending

                contentItem: RowLayout {
                    spacing: page.width < 350 ? 8 : 10

                    MobileCategoryIcon {
                        Layout.preferredWidth: page.width < 350 ? 28 : 31
                        Layout.preferredHeight: 34
                        initial: category.model.initial
                    }

                    MobileEditorialText {
                        Layout.fillWidth: true
                        text: category.text
                        font.pixelSize: page.width < 350 ? 14 : 16
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
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

                    historyEnabled: true
                    onHistoryRequested: page.historyRequested(category.model.id)
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
        spacing: 18

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
