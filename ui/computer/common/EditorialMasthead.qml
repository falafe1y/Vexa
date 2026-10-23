import QtQuick
import QtQuick.Controls
import "../dashboard"

Item {
    id: head
    required property var host
    required property var controller
    property string title: ""
    property bool planned: false
    property bool period: false
    readonly property bool narrow: host.width <= 850
    readonly property bool small: host.width <= 1150 && !narrow
    readonly property bool medium: host.width <= 1500
    readonly property bool compact: host.height <= 1000 && !narrow
    implicitHeight: narrow ? 196 : compact ? 104 : 128
    Item {
        id: titleBlock
        y: head.narrow ? 12 : parent.height - height - 8
        width: head.narrow ? parent.width : Math.max(0, filters.x - 16)
        height: head.narrow ? 64 : head.small ? 72 : head.compact ? 88 : head.medium ? 80 : 96
        EditorialText {
            objectName: "editorialPageTitle"
            height: parent.height
            width: parent.width
            text: head.title
            font.family: "PT Serif"
            font.italic: true
            font.pixelSize: head.narrow ? 52 : head.small ? Math.min(56, Math.max(40, head.host.width * .048)) : head.compact
                                                            ? 72 : head.medium ? 64 : 80
            font.letterSpacing: head.small ? -1 : -2
        }
    }
    Item {
        id: filters
        objectName: "editorialFilters"
        anchors.right: parent.right
        y: head.narrow ? 92 : parent.height - height - 8
        readonly property int gap: head.small ? 12 : 16
        readonly property int planWidth: head.small ? 128 : 144
        readonly property int currencyWidth: head.small ? 96 : head.medium ? 128 : 160
        readonly property int periodWidth: head.small ? 152 : head.medium ? 192 : 256
        width: head.narrow ? parent.width : currencyWidth + (head.period ? periodWidth + gap : 0) + (head.planned
                                                                                                     ? planWidth + gap :
                                                                                                       0)
        height: 80
        EditorialAction {
            visible: head.planned
            anchors.bottom: parent.bottom
            width: filters.planWidth
            height: 40
            leftPadding: 8
            rightPadding: 8
            text: "ПЛАНОВЫЕ"
            mono: false
            textSize: head.small ? 14 : 16
            outlined: true
            onClicked: head.host.editorialSchedule(null)
        }
        Item {
            visible: head.period
            x: head.planned ? filters.planWidth + filters.gap : 0
            height: 72
            anchors.bottom: parent.bottom
            width: filters.width - x - filters.currencyWidth - filters.gap
            EditorialText {
                height: 24
                text: "ПЕРИОД"
                font.family: "Cousine"
                font.pixelSize: 12
                color: "#59616a"
            }
            EditorialAction {
                objectName: "editorialPeriod"
                y: 24
                width: parent.width
                height: 48
                text: head.host.dateFilterLabel()
                mono: false
                textSize: 16
                arrow: false
                underline: true
                onClicked: periodMenu.open()
                EditorialText {
                    anchors.right: parent.right
                    height: 48
                    text: "⌄"
                    font.pixelSize: 14
                }
                EditorialMenu {
                    id: periodMenu
                    y: parent.height
                    width: Math.max(parent.width, 240)
                    font.family: "Arimo"
                    font.pixelSize: 16

                    EditorialMenuItem {
                        text: "Всё время"
                        onTriggered: head.controller.clearDateFilter()
                    }
                    EditorialMenuItem {
                        text: "Текущий месяц"
                        onTriggered: {
                            const now = new Date();
                            head.controller.setDateFilter(new Date(now.getFullYear(), now.getMonth(), 1), now);
                        }
                    }
                    EditorialMenuItem {
                        text: "Последние 7 дней"
                        onTriggered: {
                            const end = new Date();
                            const start = new Date();
                            start.setDate(start.getDate() - 6);
                            head.controller.setDateFilter(start, end);
                        }
                    }
                    EditorialMenuItem {
                        text: "Последние 30 дней"
                        onTriggered: {
                            const end = new Date();
                            const start = new Date();
                            start.setDate(start.getDate() - 29);
                            head.controller.setDateFilter(start, end);
                        }
                    }
                    EditorialMenuItem {
                        text: "Выбрать даты…"
                        onTriggered: head.host.editorialDateFilter()
                    }
                }
            }
        }
        Item {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: filters.currencyWidth
            height: 72
            EditorialText {
                height: 24
                text: "ВАЛЮТА"
                font.family: "Cousine"
                font.pixelSize: 12
                color: "#59616a"
            }
            EditorialChoice {
                id: currency
                objectName: "editorialCurrency"
                y: 24
                width: parent.width
                model: ["RUB", "USD", "EUR", "CNY"]
                currentIndex: Math.max(0, model.indexOf(head.controller.appCurrency))
                font.bold: true
                onActivated: head.controller.appCurrency = currentText
            }
        }
    }
    Rectangle {
        objectName: "editorialHeadingRule"
        y: parent.height
        height: 1
        width: parent.width
        color: "#031528"
    }
}
