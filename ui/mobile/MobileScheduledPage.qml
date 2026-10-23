import QtQuick
import QtQuick.Layouts

Item {
    id: page

    function create() {
        sheet.openFor(null);
    }

    readonly property var recurrenceOptions: [
        {
            label: "Ежедневно",
            value: "daily"
        },
        {
            label: "Каждую неделю",
            value: "weekly"
        },
        {
            label: "Каждый месяц",
            value: "monthly_day"
        },
        {
            label: "День недели месяца",
            value: "monthly_weekday"
        }
    ]
    readonly property var weekdayOptions: [
        {
            label: "Пн",
            value: 1
        },
        {
            label: "Вт",
            value: 2
        },
        {
            label: "Ср",
            value: 3
        },
        {
            label: "Чт",
            value: 4
        },
        {
            label: "Пт",
            value: 5
        },
        {
            label: "Сб",
            value: 6
        },
        {
            label: "Вс",
            value: 7
        }
    ]
    readonly property var weekOfMonthOptions: [
        {
            label: "Первая",
            value: 1
        },
        {
            label: "Вторая",
            value: 2
        },
        {
            label: "Третья",
            value: 3
        },
        {
            label: "Четвёртая",
            value: 4
        },
        {
            label: "Последняя",
            value: 5
        }
    ]

    function fiatAccounts() {
        const rows = financeController.allAccounts;
        const result = [];
        for (let i = 0; i < rows.length; ++i)
            if (rows[i].asset === "fiat")
                result.push(rows[i]);
        return result;
    }

    function categoriesFor(kind) {
        return financeController.categories.filter(function (item) {
            return item.type === kind;
        });
    }

    function accountCurrency(accountId) {
        const rows = fiatAccounts();
        for (let i = 0; i < rows.length; ++i)
            if (rows[i].id === accountId)
                return rows[i].currency;
        return financeController.appCurrency;
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
            model: financeController.scheduledTransactions
            footer: Item {
                width: list.width
                height: 72
            }

            delegate: MobileCard {
                id: scheduleCard

                required property var modelData
                readonly property var row: modelData

                width: list.width
                gap: 8

                TapHandler {
                    onTapped: sheet.openFor(scheduleCard.row)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileText {
                        font.family: MobileTheme.serif
                        Layout.fillWidth: true
                        text: scheduleCard.row.name
                        elide: Text.ElideRight
                        color: MobileTheme.accent
                        font.pixelSize: MobileTheme.sizeHeading
                        font.weight: Font.Normal
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: MobileFormat.displayMoney(scheduleCard.row.type === "income" ? scheduleCard.row.amount : -scheduleCard.row.amount, scheduleCard.row.currency, true)
                        color: scheduleCard.row.type === "income" ? MobileTheme.income : MobileTheme.red
                        font.pixelSize: MobileTheme.sizeBody
                        font.weight: Font.Normal
                    }
                }

                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: scheduleCard.row.scheduleText
                    wrapMode: Text.Wrap
                    color: MobileTheme.accent
                    font.pixelSize: MobileTheme.sizeCaption
                }

                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: "Следующая: %1".arg(MobileFormat.isoDate(scheduleCard.row.nextDate)) + " · " + scheduleCard.row.accountName
                    elide: Text.ElideRight
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
        icon: "calendar"
        title: "Регулярных операций пока нет"
        text: "Зарплата, аренда или подписки будут попадать в операции автоматически."
        actionText: ""
        onAction: sheet.openFor(null)
    }

    MobileSheet {
        id: sheet

        property string editingId: ""
        property string operationKind: "expense"
        property string accountId: ""
        property string categoryId: ""
        property string recurrence: "monthly_day"
        property int weekday: 1
        property int weekOfMonth: 1
        property string errorText: ""
        property bool confirmingDelete: false

        title: editingId.length > 0 ? "Регулярная операция" : "Новая регулярная операция"

        function openFor(row) {
            const accounts = page.fiatAccounts();
            editingId = row ? row.id : "";
            nameField.text = row ? row.name : "";
            operationKind = row ? row.type : "expense";
            amountField.text = row ? MobileFormat.amountText(row.amount) : "";
            accountId = row ? row.accountId : (accounts.length > 0 ? accounts[0].id : "");
            categoryId = row ? row.categoryId : "";
            recurrence = row ? row.recurrence : "monthly_day";
            weekday = row && row.weekday ? row.weekday : 1;
            weekOfMonth = row && row.weekOfMonth ? row.weekOfMonth : 1;
            dayField.text = row && row.dayOfMonth ? String(row.dayOfMonth) : "1";
            startField.text = row ? MobileFormat.isoDate(row.startsOn) : Qt.formatDate(new Date(), "dd.MM.yyyy");
            errorText = "";
            confirmingDelete = false;
            open();
        }

        function save() {
            const date = MobileFormat.dateFromInput(startField.text);
            if (!date) {
                errorText = "Укажите дату начала в формате дд.мм.гггг";
                return;
            }
            const result = financeController.saveScheduledTransaction({
                id: editingId,
                name: nameField.text,
                accountId: accountId,
                categoryId: categoryId,
                type: operationKind,
                amount: MobileFormat.minorFromText(amountField.text),
                currency: page.accountCurrency(accountId),
                recurrence: recurrence,
                weekday: weekday,
                dayOfMonth: Math.round(MobileFormat.numberFromText(dayField.text)),
                weekOfMonth: weekOfMonth,
                startsOn: MobileFormat.isoFromDate(date)
            });
            if (result.ok)
                sheet.close();
            else
                errorText = result.error || "Не удалось сохранить операцию";
        }

        MobileField {
            id: nameField
            Layout.fillWidth: true
            label: "Название"
            placeholder: "Например, аренда"
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
            value: sheet.operationKind
            onActivated: function (chosen) {
                if (sheet.operationKind !== chosen) {
                    sheet.operationKind = chosen;
                    sheet.categoryId = "";
                }
            }
        }

        MobileField {
            id: amountField
            Layout.fillWidth: true
            label: "Сумма"
            placeholder: "0"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }

        SheetLabel {
            text: "Счёт"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.fiatAccounts()

                delegate: MobileChip {
                    required property var modelData
                    text: modelData.name + " · " + modelData.currency
                    selected: sheet.accountId === modelData.id
                    onClicked: sheet.accountId = modelData.id
                }
            }
        }

        SheetLabel {
            text: "Категория"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.categoriesFor(sheet.operationKind)

                delegate: MobileChip {
                    required property var modelData
                    text: modelData.label
                    selected: sheet.categoryId === modelData.value
                    onClicked: sheet.categoryId = modelData.value
                }
            }
        }

        SheetLabel {
            text: "Повторять"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.recurrenceOptions

                delegate: MobileChip {
                    required property var modelData
                    text: modelData.label
                    selected: sheet.recurrence === modelData.value
                    onClicked: sheet.recurrence = modelData.value
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: sheet.recurrence === "weekly" || sheet.recurrence === "monthly_weekday"
            spacing: 8

            Repeater {
                model: page.weekdayOptions

                delegate: MobileChip {
                    required property var modelData
                    text: modelData.label
                    selected: sheet.weekday === modelData.value
                    onClicked: sheet.weekday = modelData.value
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: sheet.recurrence === "monthly_weekday"
            spacing: 8

            Repeater {
                model: page.weekOfMonthOptions

                delegate: MobileChip {
                    required property var modelData
                    text: modelData.label
                    selected: sheet.weekOfMonth === modelData.value
                    onClicked: sheet.weekOfMonth = modelData.value
                }
            }
        }

        MobileField {
            id: dayField
            visible: sheet.recurrence === "monthly_day"
            Layout.fillWidth: true
            label: "День месяца, 1–31"
            inputMethodHints: Qt.ImhDigitsOnly
        }

        MobileField {
            id: startField
            Layout.fillWidth: true
            label: "Дата начала"
            placeholder: "дд.мм.гггг"
        }

        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: sheet.errorText.length > 0
            text: sheet.errorText
            wrapMode: Text.Wrap
            color: MobileTheme.red
            font.pixelSize: MobileTheme.sizeCaption
        }

        MobileButton {
            Layout.fillWidth: true
            variant: "primary"
            text: "Сохранить"
            onClicked: sheet.save()
        }

        MobileButton {
            Layout.fillWidth: true
            visible: sheet.editingId.length > 0
            variant: "danger"
            text: sheet.confirmingDelete ? "Нажмите ещё раз, чтобы удалить" : "Удалить расписание"
            onClicked: {
                if (!sheet.confirmingDelete) {
                    sheet.confirmingDelete = true;
                    return;
                }
                if (financeController.deleteScheduledTransaction(sheet.editingId))
                    sheet.close();
                else
                    sheet.errorText = "Не удалось удалить расписание";
            }
        }
    }

    component SheetLabel: MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
        font.weight: Font.Medium
    }
}
