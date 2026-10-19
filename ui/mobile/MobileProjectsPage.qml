import QtQuick
import QtQuick.Layouts

Item {
    id: page

    function create() {
        projectSheet.openFor(null);
    }

    signal navigate(string key)

    function openProject(projectId) {
        financeController.selectedProjectId = projectId;
        page.navigate("project");
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
            model: financeController.projects
            footer: Item {
                width: list.width
                height: 72
            }

            delegate: MobileCard {
                id: projectCard

                required property var modelData
                readonly property var row: modelData

                width: list.width
                gap: 8

                TapHandler {
                    onTapped: page.openProject(projectCard.row.id)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileText {
                        font.family: MobileTheme.serif
                        Layout.fillWidth: true
                        text: projectCard.row.name
                        elide: Text.ElideRight
                        color: MobileTheme.accent
                        font.pixelSize: MobileTheme.sizeHeading
                        font.weight: Font.Normal
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: MobileFormat.displayMoney(projectCard.row.resultMinor, financeController.appCurrency, true)
                        color: projectCard.row.resultMinor < 0 ? MobileTheme.red : projectCard.row.resultMinor > 0 ? MobileTheme.income : MobileTheme.accent
                        font.pixelSize: MobileTheme.sizeBody
                        font.weight: Font.Normal
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileText {
                        font.family: MobileTheme.mono
                        Layout.fillWidth: true
                        text: qsTr("Доходы %1").arg(MobileFormat.displayMoney(projectCard.row.incomeMinor, financeController.appCurrency, false))
                        color: MobileTheme.muted
                        font.pixelSize: MobileTheme.sizeCaption
                        elide: Text.ElideRight
                    }
                    MobileText {
                        font.family: MobileTheme.mono
                        text: qsTr("Расходы %1").arg(MobileFormat.displayMoney(projectCard.row.expenseMinor, financeController.appCurrency, false))
                        color: MobileTheme.muted
                        font.pixelSize: MobileTheme.sizeCaption
                        elide: Text.ElideRight
                    }
                }

                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: qsTr("Операций: %1").arg(projectCard.row.operationCount)
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
        svg: "qrc:/icons/projects.svg"
        title: qsTr("Проектов пока нет")
        text: qsTr("Проект объединяет операции одной задачи или поездки в отдельную сводку.")
        actionText: ""
        onAction: projectSheet.openFor(null)
    }

    MobileSheet {
        id: projectSheet

        property string editingId: ""
        property string errorText: ""

        title: qsTr("Новый проект")

        function openFor(row) {
            editingId = row ? row.id : "";
            nameField.text = row ? row.name : "";
            errorText = "";
            open();
        }

        MobileField {
            id: nameField
            Layout.fillWidth: true
            label: qsTr("Название проекта")
            placeholder: qsTr("Например, ремонт")
        }

        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: projectSheet.errorText.length > 0
            text: projectSheet.errorText
            wrapMode: Text.Wrap
            color: MobileTheme.red
            font.pixelSize: MobileTheme.sizeCaption
        }

        MobileButton {
            Layout.fillWidth: true
            variant: "primary"
            text: qsTr("Сохранить")
            onClicked: {
                const ok = projectSheet.editingId.length > 0 ? financeController.renameProject(projectSheet.editingId, nameField.text) : financeController.addProject(nameField.text);
                if (ok)
                    projectSheet.close();
                else
                    projectSheet.errorText = qsTr("Укажите уникальное название проекта");
            }
        }
    }
}
