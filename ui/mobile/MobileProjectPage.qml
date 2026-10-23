import QtQuick
import QtQuick.Layouts

Item {
    id: page

    function create() {
        operationSheet.openNew();
    }

    signal done

    property bool confirmingDelete: false

    function findProject() {
        const rows = financeController.projects;
        for (let i = 0; i < rows.length; ++i)
            if (rows[i].id === financeController.selectedProjectId)
                return rows[i];
        return null;
    }

    readonly property var project: findProject()

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        MobileCard {
            Layout.fillWidth: true
            hard: true
            gap: 8

            MobileText {
                font.family: MobileTheme.mono
                text: "Результат проекта"
                color: MobileTheme.muted
                font.pixelSize: MobileTheme.sizeCaption
            }
            MobileText {
                font.family: MobileTheme.serif
                text: MobileFormat.displayMoney(page.project ? page.project.resultMinor : 0, financeController.appCurrency, true)
                color: page.project && page.project.resultMinor < 0 ? MobileTheme.red : MobileTheme.accent
                font.pixelSize: MobileTheme.sizeDisplay
                font.weight: Font.Bold
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    MobileText {
                        font.family: MobileTheme.mono
                        text: "Доходы"
                        color: MobileTheme.muted
                        font.pixelSize: MobileTheme.sizeCaption
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: MobileFormat.displayMoney(page.project ? page.project.incomeMinor : 0, financeController.appCurrency, false)
                        color: MobileTheme.income
                        font.pixelSize: MobileTheme.sizeBody
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    MobileText {
                        font.family: MobileTheme.mono
                        text: "Расходы"
                        color: MobileTheme.muted
                        font.pixelSize: MobileTheme.sizeCaption
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: MobileFormat.displayMoney(page.project ? page.project.expenseMinor : 0, financeController.appCurrency, false)
                        color: MobileTheme.red
                        font.pixelSize: MobileTheme.sizeBody
                        font.weight: Font.DemiBold
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MobileButton {
                    Layout.fillWidth: true
                    text: "Переименовать"
                    onClicked: renameSheet.openFor(page.project)
                }
                MobileButton {
                    Layout.fillWidth: true
                    variant: "danger"
                    text: page.confirmingDelete ? "Точно удалить?" : "Удалить"
                    onClicked: {
                        if (!page.confirmingDelete) {
                            page.confirmingDelete = true;
                            return;
                        }
                        if (page.project && financeController.deleteProject(page.project.id))
                            page.done();
                    }
                }
            }
        }

        MobileText {
            font.family: MobileTheme.mono
            text: "Операции"
            color: MobileTheme.muted
            font.pixelSize: MobileTheme.sizeLabel
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6
        }

        ListView {
            id: transactions

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            pixelAligned: true
            model: financeController.projectTransactions
            footer: Item {
                width: transactions.width
                height: 72
            }

            delegate: MobileListRow {
                required property var modelData
                required property int index

                width: transactions.width
                first: index === 0
                title: modelData.categoryName || modelData.description || "Без категории"
                subtitle: Qt.formatDateTime(new Date(modelData.date), "dd.MM.yyyy") + (modelData.description && modelData.categoryName ? " · " + modelData.description : "")
                amount: MobileFormat.transactionText(modelData)
                amountColor: modelData.type === "income" ? MobileTheme.income : modelData.type === "transfer" ? MobileTheme.muted : MobileTheme.red
            }
        }
    }

    MobileEmptyState {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: transactions.count === 0
        svg: "qrc:/icons/projects.svg"
        title: "Операций пока нет"
        text: "Добавьте доход или расход, и они попадут в сводку проекта."
        actionText: ""
        onAction: operationSheet.openNew()
    }

    MobileSheet {
        id: renameSheet

        property string errorText: ""

        title: "Название проекта"

        function openFor(row) {
            if (!row)
                return;
            renameField.text = row.name;
            errorText = "";
            open();
        }

        MobileField {
            id: renameField
            Layout.fillWidth: true
            label: "Название"
        }

        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: renameSheet.errorText.length > 0
            text: renameSheet.errorText
            wrapMode: Text.Wrap
            color: MobileTheme.red
            font.pixelSize: MobileTheme.sizeCaption
        }

        MobileButton {
            Layout.fillWidth: true
            variant: "primary"
            text: "Сохранить"
            onClicked: {
                if (page.project && financeController.renameProject(page.project.id, renameField.text))
                    renameSheet.close();
                else
                    renameSheet.errorText = "Укажите уникальное название проекта";
            }
        }
    }

    MobileSheet {
        id: operationSheet

        property string operationKind: "expense"
        property string categoryId: ""
        property string accountId: ""
        property string errorText: ""

        title: "Операция проекта"

        function categoriesFor(kind) {
            return financeController.categories.filter(function (item) {
                return item.type === kind;
            });
        }

        function setKind(kind) {
            if (operationKind === kind)
                return;
            operationKind = kind;
            categoryId = "";
        }

        function openNew() {
            operationKind = "expense";
            categoryId = "";
            accountId = "";
            errorText = "";
            amountField.text = "";
            descriptionField.text = "";
            dateField.text = Qt.formatDate(new Date(), "dd.MM.yyyy");
            open();
        }

        function save() {
            const minor = MobileFormat.minorFromText(amountField.text);
            const date = MobileFormat.dateFromInput(dateField.text);
            if (minor <= 0) {
                errorText = "Введите сумму больше нуля";
                return;
            }
            if (!date) {
                errorText = "Укажите дату в формате дд.мм.гггг";
                return;
            }
            if (categoryId.length === 0 || accountId.length === 0) {
                errorText = "Выберите категорию и счёт";
                return;
            }
            if (page.project && financeController.addProjectTransaction(page.project.id, minor, descriptionField.text, categoryId, accountId, operationKind, date))
                close();
            else
                errorText = "Не удалось сохранить операцию";
        }

        MobileSegmented {
            Layout.fillWidth: true
            options: [
                {
                    label: "Расход",
                    value: "expense"
                },
                {
                    label: "Доход",
                    value: "income"
                }
            ]
            value: operationSheet.operationKind
            onActivated: function (chosen) {
                operationSheet.setKind(chosen);
            }
        }

        MobileField {
            id: amountField
            Layout.fillWidth: true
            label: "Сумма"
            placeholder: "0"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }

        MobileField {
            id: descriptionField
            Layout.fillWidth: true
            label: "Описание"
            placeholder: "Необязательно"
        }

        MobileText {
            font.family: MobileTheme.mono
            text: "Категория"
            color: MobileTheme.muted
            font.pixelSize: MobileTheme.sizeCaption
            font.weight: Font.Medium
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: operationSheet.categoriesFor(operationSheet.operationKind)

                delegate: MobileChip {
                    required property var modelData
                    text: modelData.label
                    selected: operationSheet.categoryId === modelData.value
                    onClicked: operationSheet.categoryId = modelData.value
                }
            }
        }

        MobileText {
            font.family: MobileTheme.mono
            text: "Счёт"
            color: MobileTheme.muted
            font.pixelSize: MobileTheme.sizeCaption
            font.weight: Font.Medium
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: financeController.allAccounts

                delegate: MobileChip {
                    required property var modelData
                    text: modelData.displayName || modelData.name
                    selected: operationSheet.accountId === modelData.id
                    onClicked: operationSheet.accountId = modelData.id
                }
            }
        }

        MobileField {
            id: dateField
            Layout.fillWidth: true
            label: "Дата"
            placeholder: "дд.мм.гггг"
        }

        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: operationSheet.errorText.length > 0
            text: operationSheet.errorText
            wrapMode: Text.Wrap
            color: MobileTheme.red
            font.pixelSize: MobileTheme.sizeCaption
        }

        MobileButton {
            Layout.fillWidth: true
            variant: "primary"
            text: "Сохранить"
            onClicked: operationSheet.save()
        }
    }
}
