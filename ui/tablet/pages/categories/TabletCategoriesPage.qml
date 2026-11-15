pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger
    required property bool landscape
    signal createRequested(int type)
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)

    readonly property int pagePadding: width < 520 ? 16 : width <= 950 ? 24 : 32

    spacing: 0

    component CategoryColumn: ColumnLayout {
        id: column

        required property string title
        required property var categories

        spacing: 0

        TabletSectionHeading {
            Layout.fillWidth: true
            title: column.title
            landscape: page.landscape
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: MobileTheme.ink
        }

        Repeater {
            id: records

            model: column.categories

            delegate: ColumnLayout {
                id: category

                required property var model

                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    spacing: 6

                    MobileEditorialText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: category.model.name
                        font.pixelSize: 16
                    }

                    TabletRowActions {
                        label: "Действия с категорией " + category.model.name
                        enabled: !page.ledger.commandPending
                        onEditRequested: page.editRequested({
                            id: category.model.id,
                            name: category.model.name,
                            type: category.model.type
                        })
                        onRemoveRequested: page.removeRequested(category.model.id, category.model.name)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: MobileTheme.line
                }
            }
        }

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.topMargin: 16
            visible: page.ledger.ready && records.count === 0
            text: "Категорий пока нет."
            color: MobileTheme.muted
            wrapMode: Text.Wrap
        }
    }

    Flickable {
        id: scroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: content.implicitHeight + 18 + page.pagePadding
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

        ColumnLayout {
            id: content

            x: page.pagePadding
            y: 18
            width: scroll.width - 2 * x
            spacing: 0

            TabletPageHeader {
                Layout.fillWidth: true
                landscape: page.landscape
                title: "Категории."
            }

            MobileActionButton {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                visible: page.landscape
                text: "+ НОВАЯ КАТЕГОРИЯ"
                enabled: page.ledger.ready && !page.ledger.commandPending
                onClicked: page.createRequested(1)
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                visible: page.landscape
                color: MobileTheme.ink
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: page.width < 580 ? 10 : 22

                CategoryColumn {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    title: "Доходы"
                    categories: page.ledger.incomeCategoriesModel
                }

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 1
                    color: MobileTheme.line
                }

                CategoryColumn {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    title: "Расходы"
                    categories: page.ledger.expenseCategoriesModel
                }
            }
        }
    }

    MobileActionButton {
        Layout.fillWidth: true
        Layout.leftMargin: page.pagePadding
        Layout.rightMargin: page.pagePadding
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: !page.landscape
        text: "+ НОВАЯ КАТЕГОРИЯ"
        outlined: false
        enabled: page.ledger.ready && !page.ledger.commandPending
        onClicked: page.createRequested(1)
    }
}
