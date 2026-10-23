import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../dashboard"

EditorialPage {
    id: page
    property bool budget: true
    readonly property var entries: budget ? controller.budgets : controller.projects
    readonly property var selected: budget ? host.selectedBudget() : host.selectedProject()
    readonly property var operations: budget ? controller.budgetTransactions : controller.projectTransactions
    title: budget ? "Бюджеты." : "Проекты."
    RowLayout {
        width: parent.width
        spacing: 0
        Item {
            Layout.preferredWidth: page.host.width <= 1150 ? 240 : page.host.width <= 1500 ? 280 : 312
            Layout.fillHeight: true
            Layout.minimumHeight: 650
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: "#031528"
            }
            Column {
                id: picker
                x: 0
                y: 24
                width: parent.width - 24
                Item {
                    width: parent.width
                    height: 48
                    EditorialText {
                        height: 32
                        text: page.budget ? "МОИ БЮДЖЕТЫ" : "МОИ ПРОЕКТЫ"
                        font.family: "Cousine"
                        font.pixelSize: 12
                    }
                    EditorialAction {
                        anchors.right: parent.right
                        text: page.budget ? "+ БЮДЖЕТ" : "+ ПРОЕКТ"
                        onClicked: page.host.editorialNewLedger(page.budget)
                    }
                }
                Repeater {
                    model: page.entries
                    delegate: Item {
                        id: entry
                        required property var modelData
                        readonly property bool selected: page.selected && page.selected.id === modelData.id
                        width: picker.width
                        height: page.budget ? 144 : 112
                        Rectangle {
                            anchors.fill: parent
                            color: entry.selected ? "#09031528" : "transparent"
                        }
                        Rectangle {
                            y: parent.height - (entry.selected ? 2 : 1)
                            width: parent.width
                            height: entry.selected ? 2 : 1
                            color: entry.selected ? "#031528" : "#bbb5a8"
                        }
                        Column {
                            x: 12
                            y: 16
                            width: parent.width - 24
                            spacing: 8
                            EditorialText {
                                width: parent.width
                                height: 32
                                text: entry.modelData.name
                                font.family: "PT Serif"
                                font.pixelSize: 24
                            }
                            EditorialText {
                                width: parent.width
                                height: 24
                                text: page.budget ? page.host.money(entry.modelData.displaySpentMinor,
                                                                    entry.modelData.displayCurrency, false) + " / "
                                                    + page.host.money(entry.modelData.displayLimitMinor,
                                                                      entry.modelData.displayCurrency, false) : "%1 операций".arg(entry.modelData.operationCount)
                                font.family: "Cousine"
                                font.pixelSize: 12
                                color: "#59616a"
                            }
                            Rectangle {
                                visible: page.budget
                                width: parent.width
                                height: 4
                                color: "#bbb5a8"
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, entry.modelData.progress || 0))
                                    height: 4
                                    color: "#031528"
                                }
                            }
                            EditorialText {
                                width: parent.width
                                height: 24
                                text: page.budget ? (entry.modelData.allAccounts ? "ВСЕ СЧЕТА" : "СЧЕТОВ: %1".arg((
                                                                                                             entry.modelData.accountIds
                                                                                                             || []).length)) :
                                                    "Результат %1".arg(page.host.money(entry.modelData.resultMinor,
                                                                                             page.controller.appCurrency,
                                                                                             false))
                                font.family: "Cousine"
                                font.pixelSize: 12
                                color: "#59616a"
                            }
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (event) {
                                if (page.budget)
                                    page.controller.selectedBudgetId = entry.modelData.id;
                                else
                                    page.controller.selectedProjectId = entry.modelData.id;
                                if (event.button === Qt.RightButton) {
                                    if (page.budget)
                                        page.host.openBudgetContextMenu(entry.modelData, mouse, event.x, event.y);
                                    else
                                        page.host.openProjectContextMenu(entry.modelData, mouse, event.x, event.y);
                                }
                            }
                        }
                    }
                }
            }
            implicitHeight: picker.height + 48
        }
        Column {
            id: detail
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: 24
            Layout.preferredHeight: implicitHeight
            spacing: 0
            Item {
                width: parent.width
                height: 96
                EditorialText {
                    width: Math.max(0, parent.width - (page.budget ? month.width : add.width) - 24)
                    height: parent.height
                    text: page.selected ? page.selected.name : page.budget ? "Бюджет не выбран" : "Проект не выбран"
                    font.family: "PT Serif"
                    font.pixelSize: page.small ? 28 : 36
                }
                RowLayout {
                    id: month
                    visible: page.budget
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16
                    EditorialAction {
                        text: "‹"
                        textSize: 24
                        arrow: false
                        implicitWidth: 32
                        onClicked: page.host.shiftBudgetMonth(-1)
                    }
                    EditorialText {
                        text: page.host.budgetMonthLabel()
                        font.family: "Cousine"
                        font.pixelSize: 14
                    }
                    EditorialAction {
                        text: "›"
                        textSize: 24
                        arrow: false
                        implicitWidth: 32
                        onClicked: page.host.shiftBudgetMonth(1)
                    }
                }
                EditorialAction {
                    id: add
                    visible: !page.budget && !!page.selected
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+ НОВАЯ ОПЕРАЦИЯ"
                    onClicked: page.host.editorialProjectOperation()
                }
            }
            EditorialMetrics {
                width: parent.width
                height: implicitHeight
                visible: !!page.selected
                metrics: !page.selected ? [] : page.budget ? [
                                                                 {
                                                                     label: "Лимит",
                                                                     value: page.host.money(
                                                                                page.selected.displayLimitMinor,
                                                                                page.selected.displayCurrency, false)
                                                                 },
                                                                 {
                                                                     label: "Потрачено",
                                                                     value: page.host.money(
                                                                                page.selected.displaySpentMinor,
                                                                                page.selected.displayCurrency, false)
                                                                 },
                                                                 {
                                                                     label: "Осталось",
                                                                     value: page.host.money(
                                                                                page.selected.displayLimitMinor
                                                                                - page.selected.displaySpentMinor,
                                                                                page.selected.displayCurrency, false)
                                                                 }
                                                             ] : [
                                                                 {
                                                                     label: "Доходы проекта",
                                                                     value: page.host.money(page.selected.incomeMinor,
                                                                                            page.controller.appCurrency,
                                                                                            false),
                                                                     color: "#2e5947"
                                                                 },
                                                                 {
                                                                     label: "Расходы проекта",
                                                                     value: page.host.money(page.selected.expenseMinor,
                                                                                            page.controller.appCurrency,
                                                                                            false)
                                                                 },
                                                                 {
                                                                     label: "Результат проекта",
                                                                     value: page.host.money(page.selected.resultMinor,
                                                                                            page.controller.appCurrency,
                                                                                            false)
                                                                 }
                                                             ]
            }
            EditorialText {
                visible: !!page.selected && !!page.selected.rateMissing
                width: parent.width
                height: visible ? 48 : 0
                text: "Проверьте курсы валют: часть сумм не пересчитана."
                color: "#b84932"
            }
            Item {
                width: 1
                height: 24
                visible: page.budget && !!page.selected
            }
            EditorialSection {
                width: parent.width
                visible: page.budget && !!page.selected
                title: "Категории"
                number: 1
            }
            Repeater {
                model: page.budget && page.selected ? page.selected.categoryLimits : []
                delegate: Item {
                    required property var modelData
                    width: detail.width
                    height: 88
                    EditorialText {
                        width: Math.max(0, parent.width - amount.width - 16)
                        height: 48
                        text: modelData.name
                    }
                    EditorialText {
                        id: amount
                        anchors.right: parent.right
                        height: 48
                        text: page.host.money(modelData.spentMinor, page.selected.currency, false) + (
                                  modelData.limitMinor > 0 ? " / " + page.host.money(modelData.limitMinor,
                                                                                     page.selected.currency, false) :
                                                             "")
                        font.family: "Cousine"
                        font.pixelSize: 14
                    }
                    Rectangle {
                        y: 56
                        width: parent.width
                        height: 4
                        color: "#bbb5a8"
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, modelData.progress || 0))
                            height: 4
                            color: "#031528"
                        }
                    }
                    Rectangle {
                        y: parent.height - 1
                        width: parent.width
                        height: 1
                        color: "#bbb5a8"
                    }
                }
            }
            Item {
                width: 1
                height: 24
            }
            EditorialSection {
                width: parent.width
                title: page.budget ? "Операции бюджета" : "Операции проекта"
                number: page.budget ? 2 : 1
                note: "%1 ОПЕРАЦИЙ".arg(page.operations.length)
            }
            EditorialOperations {
                width: parent.width
                host: page.host
                rows: page.operations
                viewport: page
                amountKey: page.budget ? "budgetAmountMinor" : "displayAmount"
                currency: page.budget && page.selected ? page.selected.currency : page.controller.appCurrency
            }
        }
    }
}
