import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../dashboard"
import "../dashboard/DashboardData.js" as Data

EditorialPage {
    id: page
    required property var theme
    host: theme
    title: qsTr("Цели.")
    readonly property int columns: host.width <= 850 ? 1 : host.width <= 1150 ? 2 : 3
    Component.onCompleted: controller.refreshInvestmentQuotes()
    function money(value, currency) {
        const converted = Data.convertMinor(value, currency, controller.appCurrency, controller.currentCurrencyRates);
        return converted === null ? "—" : theme.money(converted, controller.appCurrency, false);
    }
    function status(row) {
        return !row.complete ? qsTr("НЕПОЛНЫЙ РАСЧЁТ") : row.achieved ? qsTr("ЦЕЛЬ ДОСТИГНУТА") : row.overdue ? qsTr(
                                                                                                                    "СРОК ИСТЁК") :
                                                                                                                qsTr("В ПРОЦЕССЕ");
    }
    function openDeletion(row) {
        deletion.goalId = row.id;
        deletion.goalName = row.name;
        deletion.errorText = "";
        deletion.open();
    }
    function openGoalContextMenu(row, source, x, y) {
        const point = source.mapToItem(page, x, y);
        goalContextMenu.goalData = row;
        goalContextMenu.x = Math.max(0, Math.min(point.x, page.width - 224));
        goalContextMenu.y = point.y;
        goalContextMenu.open();
    }
    component Action: StyledButton {
        neo: true
        cornerRadius: 8
        font.weight: Font.DemiBold
        leftPadding: 14
        rightPadding: 14
        appTextColor: theme.accent
        appMutedColor: theme.muted
        appPanelColor: theme.panel
        appSoftColor: theme.soft
        appLineColor: theme.line
        appAccentColor: theme.accent
        appHoverColor: theme.controlHovered
        appOnAccentColor: theme.white
        appErrorColor: theme.red
    }
    component GoalMenuItem: MenuItem {
        id: menuItem
        property bool destructive: false
        hoverEnabled: true
        implicitHeight: 40
        leftPadding: 12
        rightPadding: 12
        contentItem: Text {
            text: menuItem.text
            color: !menuItem.enabled ? theme.muted : menuItem.highlighted || menuItem.hovered ? theme.white :
                                                                                                menuItem.destructive
                                                                                                ? theme.red :
                                                                                                  theme.accent
            font.pixelSize: 14
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: menuItem.highlighted || menuItem.hovered ? (menuItem.destructive ? theme.red : theme.accent) :
                                                              "transparent"

        }
    }

    Item {
        width: parent.width
        height: 80
        EditorialText {
            width: Math.max(0, parent.width - add.width - 24)
            height: 80
            text: qsTr("Текущий капитал по выбранным источникам.")
            color: "#59616a"
        }
        EditorialAction {
            id: add
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("+ ЦЕЛЬ")
            onClicked: editor.openForm(null)
        }
        Rectangle {
            y: 79
            width: parent.width
            height: 1
            color: "#031528"
        }
    }
    Grid {
        id: grid
        width: parent.width
        columns: page.columns
        spacing: 0
        Repeater {
            model: page.controller.financialGoals
            delegate: Item {
                id: card
                required property var modelData
                required property int index
                width: grid.width / page.columns
                height: 392
                Rectangle {
                    visible: (card.index + 1) % page.columns !== 0
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: "#031528"
                }
                Rectangle {
                    y: parent.height - 1
                    width: parent.width
                    height: 1
                    color: "#031528"
                }
                Column {
                    x: card.index % page.columns === 0 ? 0 : 24
                    y: 24
                    width: parent.width - x - ((card.index + 1) % page.columns === 0 ? 0 : 24)
                    spacing: 12
                    Item {
                        width: parent.width
                        height: 24
                        EditorialText {
                            height: 24
                            text: String(card.index + 1).padStart(2, "0") + " / " + qsTr("ЦЕЛЬ")
                            font.family: "Cousine"
                            font.pixelSize: 12
                            color: "#59616a"
                        }
                        EditorialText {
                            anchors.right: parent.right
                            height: 24
                            text: page.status(card.modelData)
                            font.family: "Cousine"
                            font.pixelSize: 12
                            color: card.modelData.achieved ? "#2e5947" : "#59616a"
                        }
                    }
                    EditorialText {
                        width: parent.width
                        height: 72
                        text: card.modelData.name
                        font.family: "PT Serif"
                        font.pixelSize: 30
                        wrapMode: Text.WordWrap
                    }
                    EditorialText {
                        width: parent.width
                        height: 48
                        text: (card.modelData.complete ? "" : qsTr("Известно: ")) + page.money(
                                  card.modelData.currentMinor, card.modelData.currency)
                        font.family: "PT Serif"
                        font.pixelSize: 36
                    }
                    EditorialText {
                        width: parent.width
                        height: 24
                        text: qsTr("из %1").arg(page.money(card.modelData.targetMinor, card.modelData.currency))
                        font.pixelSize: 14
                        color: "#59616a"
                    }
                    Rectangle {
                        width: parent.width
                        height: 4
                        color: "#bbb5a8"
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, card.modelData.ratio))
                            height: 4
                            color: "#031528"
                        }
                    }
                    Item {
                        width: parent.width
                        height: 24
                        EditorialText {
                            height: 24
                            text: Math.max(0, card.modelData.ratio * 100).toFixed(1).replace(".", ",") + " %"
                            font.family: "Cousine"
                            font.pixelSize: 12
                            color: "#59616a"
                        }
                        EditorialText {
                            anchors.right: parent.right
                            height: 24
                            text: card.modelData.deadline ? qsTr("До %1").arg(card.modelData.deadline.split("-").reverse(
                                                                                  ).join(".")) : qsTr("Без срока")
                            font.family: "Cousine"
                            font.pixelSize: 12
                            color: "#59616a"
                        }
                    }
                    EditorialText {
                        width: parent.width
                        height: 24
                        text: qsTr("Осталось %1").arg(page.money(card.modelData.remainingMinor,
                                                                 card.modelData.currency))

                        font.family: "Cousine"
                        font.pixelSize: 12
                        color: "#59616a"
                    }
                    EditorialAction {
                        text: qsTr("РЕДАКТИРОВАТЬ")
                        onClicked: editor.openForm(card.modelData)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: function (event) {
                        page.openGoalContextMenu(card.modelData, this, event.x, event.y);
                    }
                }
            }
        }
    }
    EditorialText {
        width: parent.width
        height: 96
        visible: controller.financialGoals.length === 0
        text: qsTr("Создайте цель и выберите счета, которые нужно учитывать.")
        color: "#59616a"
    }
    Menu {
        id: goalContextMenu
        parent: page
        width: 224
        padding: 6
        property var goalData: null
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        GoalMenuItem {
            width: goalContextMenu.availableWidth
            text: qsTr("Редактировать")
            enabled: goalContextMenu.goalData !== null
            onTriggered: {
                if (goalContextMenu.goalData)
                    editor.openForm(goalContextMenu.goalData);
            }
        }

        MenuSeparator {
            width: goalContextMenu.availableWidth
            topPadding: 4
            bottomPadding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: theme.line
            }
        }

        GoalMenuItem {
            width: goalContextMenu.availableWidth
            text: qsTr("Удалить")
            destructive: true
            enabled: goalContextMenu.goalData !== null
            onTriggered: {
                if (goalContextMenu.goalData)
                    page.openDeletion(goalContextMenu.goalData);
            }
        }

        background: Rectangle {
            HardShadow {
                depth: 4
                shadowColor: theme.accent
            }

            color: theme.panel
            radius: 12
            border.width: 1
            border.color: theme.accent
        }
    }
    FinancialGoalDialog {
        id: editor
        controller: page.controller
        theme: page.theme
        parent: Overlay.overlay
    }
    Dialog {
        id: deletion
        parent: Overlay.overlay
        property string goalId: ""
        property string goalName: ""
        property string errorText: ""
        width: Math.min(470, parent ? parent.width - 40 : 470)
        anchors.centerIn: parent
        modal: true
        padding: 24
        background: Rectangle {
            HardShadow {
                depth: 6
                shadowColor: theme.accent
            }
            radius: 16
            color: theme.panel
            border.width: 1
            border.color: theme.accent
        }
        contentItem: ColumnLayout {
            spacing: 14
            Text {
                text: qsTr("Удалить цель?")
                color: theme.accent
                font.pixelSize: 21
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: deletion.goalName
                color: theme.accent
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Счета, деньги и операции останутся без изменений.")
                color: theme.muted
                wrapMode: Text.WordWrap
            }
            Text {
                visible: deletion.errorText.length > 0
                text: deletion.errorText
                color: theme.red
            }
            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                Action {
                    text: qsTr("Отмена")
                    onClicked: deletion.close()
                }
                Action {
                    text: qsTr("Удалить")
                    destructive: true
                    onClicked: {
                        if (controller.deleteFinancialGoal(deletion.goalId))
                            deletion.close();
                        else
                            deletion.errorText = qsTr("Не удалось удалить цель");
                    }
                }
            }
        }
    }
}
