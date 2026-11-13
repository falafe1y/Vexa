
import QtQuick
import QtQuick.Controls
import UI

Flickable {
    id: page
    required property var ledger
    signal createRequested()
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)
    readonly property bool narrow: width <= 650
    readonly property bool small: width <= 950 && !narrow
    readonly property bool medium: width <= 1300
    readonly property bool compact: height <= 1000 && !narrow
    readonly property int pad: narrow ? 20 : small ? 24 : medium ? 32 : 48
    readonly property int mainWidth: width - pad * 2

    clip: true
    contentWidth: width
    contentHeight: Math.max(height, paper.y + paper.height + 24)
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOff
    }

    Item {
        id: paper

        x: page.pad
        y: 24
        width: page.mainWidth
        height: categoriesSection.y + categoriesSection.height

        Item {
            id: masthead

            width: parent.width
            height: page.narrow ? 196 : page.compact ? 104 : 128

            EditorialText {
                y: page.narrow ? 12 : masthead.height - height - 8

                width: parent.width
                height: page.narrow ? 64 : page.compact ? 88 : 96

                text: "Категории."

                font.family: DesktopTheme.serif
                font.italic: true
                font.letterSpacing: -2

                font.pixelSize: page.narrow ? 52
                    : page.small ? 56
                    : page.compact ? 72
                    : page.medium ? 64 : 80

                fontSizeMode: Text.Fit
                minimumPixelSize: 28
                color: DesktopTheme.ink
            }

            Rectangle {
                y: parent.height
                width: parent.width
                height: 1
                color: DesktopTheme.ink
            }
        }

        Item {
            id: toolbar

            y: masthead.height + 1
            width: parent.width
            height: 64

            ActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: "+ КАТЕГОРИЯ"

                enabled: page.ledger.ready
                         && !page.ledger.commandPending

                onClicked: page.createRequested()
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: DesktopTheme.ink
            }
        }

        Item {
            id: categoriesSection

            y: toolbar.y + toolbar.height
            width: parent.width

            height: Math.max(
                page.height - paper.y - y,
                Math.max(incomeColumn.implicitHeight, expenseColumn.implicitHeight) + 24
            )

            readonly property real columnWidth: width / 2

            Column {
                id: incomeColumn

                x: 0
                y: 24

                width: categoriesSection.columnWidth - 24
                spacing: 0

                Item {
                    width: parent.width
                    height: 40

                    EditorialText {
                        anchors.fill: parent
                        text: "01.  ДОХОДЫ"

                        font.bold: true
                        font.pixelSize: 16
                        color: DesktopTheme.ink
                    }
                }

                Repeater {
                    model: page.ledger.categoriesModel

                    delegate: Item {
                        id: incomeRow

                        required property var model

                        visible: model.type === 0

                        width: incomeColumn.width
                        height: visible ? 56 : 0

                        EditorialText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            height: parent.height

                            text: incomeRow.model.name
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }


                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            enabled: !page.ledger.commandPending
                            onTapped: (point, button) =>
                                incomeContextMenu.openAt(point.position.x, point.position.y)
                        }

                        ContextActionMenu {
                            id: incomeContextMenu
                            editEnabled: !page.ledger.commandPending
                            onEditRequested: page.editRequested({
                                id: incomeRow.model.id,
                                name: incomeRow.model.name,
                                type: incomeRow.model.type
                            })
                            removeEnabled: !page.ledger.commandPending
                            onRemoveRequested: page.removeRequested(
                                incomeRow.model.id, incomeRow.model.name)
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: DesktopTheme.line
                        }
                    }
                }
            }

            Rectangle {
                x: categoriesSection.columnWidth
                width: 1
                height: categoriesSection.height
                color: DesktopTheme.ink
            }

            Column {
                id: expenseColumn

                x: categoriesSection.columnWidth + 24
                y: 24

                width: categoriesSection.columnWidth - 24
                spacing: 0

                Item {
                    width: parent.width
                    height: 40

                    EditorialText {
                        anchors.fill: parent
                        text: "02.  РАСХОДЫ"

                        font.bold: true
                        font.pixelSize: 16
                        color: DesktopTheme.ink
                    }
                }

                Repeater {
                    model: page.ledger.categoriesModel

                    delegate: Item {
                        id: expenseRow

                        required property var model

                        visible: model.type === 1

                        width: expenseColumn.width
                        height: visible ? 56 : 0

                        EditorialText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            height: parent.height

                            text: expenseRow.model.name
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }


                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            enabled: !page.ledger.commandPending
                            onTapped: (point, button) =>
                                expenseContextMenu.openAt(point.position.x, point.position.y)
                        }

                        ContextActionMenu {
                            id: expenseContextMenu
                            editEnabled: !page.ledger.commandPending
                            onEditRequested: page.editRequested({
                                id: expenseRow.model.id,
                                name: expenseRow.model.name,
                                type: expenseRow.model.type
                            })
                            removeEnabled: !page.ledger.commandPending
                            onRemoveRequested: page.removeRequested(
                                expenseRow.model.id, expenseRow.model.name)
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: DesktopTheme.line
                        }
                    }
                }
            }
        }
    }
}
