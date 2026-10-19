import QtQuick
import QtQuick.Layouts

Item {
    id: page

    function create() {
        goalSheet.openFor(null);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            boundsBehavior: Flickable.StopAtBounds
            pixelAligned: true
            model: financeController.financialGoals
            footer: Item {
                width: list.width
                height: 72
            }

            delegate: MobileCard {
                id: goalCard

                required property var modelData
                readonly property var row: modelData

                width: list.width
                gap: 12

                TapHandler {
                    onTapped: goalSheet.openFor(goalCard.row)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileText {
                        font.family: MobileTheme.serif
                        Layout.fillWidth: true
                        text: goalCard.row.name
                        elide: Text.ElideRight
                        color: MobileTheme.accent
                        font.pixelSize: MobileTheme.sizeHeading
                        font.weight: Font.Normal
                    }
                    MobileText {
                        font.family: MobileTheme.mono
                        visible: goalCard.row.achieved || goalCard.row.overdue
                        text: goalCard.row.achieved ? qsTr("Достигнута") : qsTr("Срок прошёл")
                        color: goalCard.row.achieved ? MobileTheme.income : MobileTheme.red
                        font.pixelSize: MobileTheme.sizeCaption
                        font.weight: Font.Normal
                    }
                }

                MobileText {
                    font.family: MobileTheme.serif
                    Layout.fillWidth: true
                    text: Number(goalCard.row.ratio * 100).toLocaleString(MobileFormat.locale(), "f", 1) + " %"
                    font.pixelSize: 40
                }

                MobileProgress {
                    Layout.fillWidth: true
                    value: goalCard.row.ratio
                    fill: goalCard.row.achieved ? MobileTheme.income : MobileTheme.accent
                }

                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: goalCard.row.remainingMinor > 0 ? qsTr("Осталось %1").arg(MobileFormat.displayMoney(goalCard.row.remainingMinor, goalCard.row.currency, false)) : qsTr("Цель достигнута")
                    color: MobileTheme.muted
                    font.pixelSize: MobileTheme.sizeCaption
                }

                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: goalCard.row.deadline ? qsTr("Срок: %1").arg(MobileFormat.isoDate(goalCard.row.deadline)) : qsTr("Без срока")
                    color: MobileTheme.muted
                    font.pixelSize: MobileTheme.sizeCaption
                }
            }
        }
    }

    MobileEmptyState {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: list.count === 0
        svg: "qrc:/icons/goals.svg"
        title: qsTr("Целей пока нет")
        text: qsTr("Укажите сумму и срок, а приложение покажет, сколько осталось накопить.")
        actionText: ""
        onAction: goalSheet.openFor(null)
    }

    MobileGoalSheet {
        id: goalSheet
    }
}
