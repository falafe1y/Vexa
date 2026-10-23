import QtQuick
import QtQuick.Layouts

MobileSheet {
    id: sheet

    property string editingId: ""
    property string currencyCode: "RUB"
    property bool allAccountsChecked: true
    property bool allCategoriesChecked: true
    property string errorText: ""
    property bool confirmingDelete: false

    title: editingId.length > 0 ? "Бюджет" : "Новый бюджет"

    ListModel {
        id: accountModel
    }

    ListModel {
        id: categoryModel
    }

    function openFor(row) {
        const accountIds = row ? row.accountIds : [];
        const limits = row ? row.categoryLimits : [];
        editingId = row ? row.id : "";
        currencyCode = row ? row.currency : "RUB";
        nameField.text = row ? row.name : "";
        limitField.text = row ? MobileFormat.amountText(row.limitMinor) : "";
        allAccountsChecked = row ? row.allAccounts : true;
        allCategoriesChecked = row ? row.allCategories : true;
        errorText = "";
        confirmingDelete = false;
        // The operations list below follows the budget being edited
        if (editingId.length > 0)
            financeController.selectedBudgetId = editingId;

        accountModel.clear();
        const accounts = financeController.allAccounts;
        for (let i = 0; i < accounts.length; ++i) {
            const account = accounts[i];
            accountModel.append({
                accountId: account.id,
                title: account.displayName || account.name,
                selected: accountIds.indexOf(account.id) >= 0
            });
        }

        categoryModel.clear();
        const categories = financeController.categories;
        for (let j = 0; j < categories.length; ++j) {
            const category = categories[j];
            if (category.type !== "expense")
                continue;
            const limit = limits.find(function (item) {
                return item.categoryId === category.value;
            });
            const configured = !!limit && limit.configured;
            categoryModel.append({
                categoryId: category.value,
                title: category.label,
                selected: configured,
                limitText: configured ? MobileFormat.amountText(limit.limitMinor) : ""
            });
        }
        open();
    }

    function save() {
        const accountIds = [];
        for (let i = 0; i < accountModel.count; ++i) {
            const account = accountModel.get(i);
            if (account.selected)
                accountIds.push(account.accountId);
        }
        const categoryLimits = [];
        for (let j = 0; j < categoryModel.count; ++j) {
            const category = categoryModel.get(j);
            if (category.selected)
                categoryLimits.push({
                    categoryId: category.categoryId,
                    limitMinor: MobileFormat.minorFromText(category.limitText)
                });
        }
        const result = financeController.saveBudget({
            id: editingId,
            name: nameField.text,
            currency: currencyCode,
            limitMinor: MobileFormat.minorFromText(limitField.text),
            allAccounts: allAccountsChecked,
            accountIds: accountIds,
            allCategories: allCategoriesChecked,
            categoryLimits: categoryLimits
        });
        if (result.ok)
            sheet.close();
        else
            errorText = result.error || "Не удалось сохранить бюджет";
    }

    MobileField {
        id: nameField
        Layout.fillWidth: true
        label: "Название"
        placeholder: "Например, продукты"
    }

    MobileSegmented {
        Layout.fillWidth: true
        options: [
            {
                label: "RUB",
                value: "RUB"
            },
            {
                label: "USD",
                value: "USD"
            },
            {
                label: "EUR",
                value: "EUR"
            },
            {
                label: "CNY",
                value: "CNY"
            }
        ]
        value: sheet.currencyCode
        onActivated: function (chosen) {
            sheet.currencyCode = chosen;
        }
    }

    MobileField {
        id: limitField
        Layout.fillWidth: true
        label: "Лимит на месяц"
        placeholder: "0"
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    MobileCheckRow {
        Layout.fillWidth: true
        label: "Все счета"
        checked: sheet.allAccountsChecked
        onToggled: function (nowChecked) {
            sheet.allAccountsChecked = nowChecked;
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: !sheet.allAccountsChecked
        spacing: 0

        Repeater {
            model: accountModel

            delegate: MobileCheckRow {
                required property int index
                required property string title
                required property bool selected

                Layout.fillWidth: true
                label: title
                checked: selected
                onToggled: function (nowChecked) {
                    accountModel.setProperty(index, "selected", nowChecked);
                }
            }
        }
    }

    MobileCheckRow {
        Layout.fillWidth: true
        label: "Все категории расходов"
        checked: sheet.allCategoriesChecked
        onToggled: function (nowChecked) {
            sheet.allCategoriesChecked = nowChecked;
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: !sheet.allCategoriesChecked
        spacing: 4

        Repeater {
            model: categoryModel

            delegate: RowLayout {
                required property int index
                required property string title
                required property bool selected
                required property string limitText

                Layout.fillWidth: true
                spacing: 8

                MobileCheckRow {
                    Layout.fillWidth: true
                    label: title
                    checked: selected
                    onToggled: function (nowChecked) {
                        categoryModel.setProperty(index, "selected", nowChecked);
                    }
                }

                MobileField {
                    visible: selected
                    Layout.preferredWidth: 112
                    placeholder: "0"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    text: limitText
                    onTextChanged: categoryModel.setProperty(index, "limitText", text)
                }
            }
        }
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
        text: sheet.confirmingDelete ? "Нажмите ещё раз, чтобы удалить" : "Удалить бюджет"
        onClicked: {
            if (!sheet.confirmingDelete) {
                sheet.confirmingDelete = true;
                return;
            }
            if (financeController.deleteBudget(sheet.editingId))
                sheet.close();
            else
                sheet.errorText = "Не удалось удалить бюджет";
        }
    }

    MobileText {
        font.family: MobileTheme.serif
        Layout.fillWidth: true
        visible: sheet.editingId.length > 0
        text: "Операции бюджета"
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeHeading
        font.weight: Font.DemiBold
    }

    Repeater {
        model: sheet.editingId.length > 0 ? financeController.budgetTransactions : []

        delegate: RowLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: modelData.description
                    color: MobileTheme.accent
                    font.pixelSize: MobileTheme.sizeBody
                    elide: Text.ElideRight
                }
                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: Qt.formatDate(new Date(modelData.date), "dd.MM.yyyy") + " · " + modelData.categoryName
                    color: MobileTheme.muted
                    font.pixelSize: MobileTheme.sizeCaption
                    elide: Text.ElideRight
                }
            }
            MobileText {
                font.family: MobileTheme.sans
                text: MobileFormat.money(modelData.budgetAmountMinor, modelData.budgetCurrency, false)
                color: MobileTheme.accent
                font.pixelSize: MobileTheme.sizeBody
                font.weight: Font.DemiBold
            }
        }
    }
}
