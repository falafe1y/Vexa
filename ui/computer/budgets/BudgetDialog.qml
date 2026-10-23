import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

EditorialDialog {
    id: dialog; objectName: "dialog"
    width: Math.min(760, parent ? parent.width - 40 : 760)
    height: Math.min(780, parent ? parent.height - 40 : 780)
    modal: true
    anchors.centerIn: parent
    padding: 0
    closePolicy: Popup.CloseOnEscape

    required property var controller
    property color panelColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF8")
    property color softColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF0")
    property color textColor: "#031528"
    property color mutedColor: (Appearance.desktop ? "#59616a" : "#687483")
    property color lineColor: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color accentColor: "#031528"
    property color errorColor: (Appearance.desktop ? "#b84932" : "#B94F48")
    property string editingId: ""

    ListModel { id: accountSelection; objectName: "accountSelection" }
    ListModel { id: categorySelection; objectName: "categorySelection" }

    function contains(values, value) {
        if (!values)
            return false;
        for (let i = 0; i < values.length; ++i)
            if (values[i] === value)
                return true;
        return false;
    }

    function amountForInput(minor) {
        const value = Math.max(0, Math.round(Number(minor)));
        const whole = Math.floor(value / 100);
        const cents = value % 100;
        return cents === 0 ? String(whole)
                           : String(whole) + ","
                             + (cents < 10 ? "0" : "") + cents;
    }

    function limitFor(categoryRows, categoryId) {
        if (!categoryRows)
            return null;
        for (let i = 0; i < categoryRows.length; ++i) {
            if (categoryRows[i].categoryId === categoryId
                    && categoryRows[i].configured)
                return categoryRows[i].limitMinor;
        }
        return null;
    }

    function rebuildSelections(row) {
        accountSelection.clear();
        const accounts = controller.allAccounts;
        for (let i = 0; i < accounts.length; ++i) {
            accountSelection.append({
                accountId: accounts[i].id,
                label: accounts[i].name + " · " + accounts[i].currency,
                selected: row ? contains(row.accountIds, accounts[i].id) : false
            });
        }

        categorySelection.clear();
        const categories = controller.categories;
        for (let j = 0; j < categories.length; ++j) {
            if (categories[j].type !== "expense"
                    || categories[j].value === "transfer-out"
                    || categories[j].value === "transfer-in")
                continue;
            const savedLimit = row
                ? limitFor(row.categoryLimits, categories[j].value) : null;
            categorySelection.append({
                categoryId: categories[j].value,
                label: categories[j].label,
                selected: savedLimit !== null,
                limitText: savedLimit !== null && Number(savedLimit) > 0
                         ? amountForInput(savedLimit) : ""
            });
        }
    }

    function openForNew() {
        editingId = "";
        nameField.clear();
        amountField.clear();
        currencyBox.currentIndex = Math.max(
            0, currencyBox.model.indexOf(controller.appCurrency));
        allAccountsBox.checked = true;
        allCategoriesBox.checked = true;
        rebuildSelections(null);
        formError.text = "";
        open();
        Qt.callLater(function() { nameField.forceActiveFocus(); });
    }

    function openForEdit(row) {
        if (!row)
            return;
        editingId = row.id;
        nameField.text = row.name;
        amountField.text = amountForInput(row.limitMinor);
        currencyBox.currentIndex = Math.max(
            0, currencyBox.model.indexOf(row.currency));
        allAccountsBox.checked = row.allAccounts;
        allCategoriesBox.checked = row.allCategories;
        rebuildSelections(row);
        formError.text = "";
        open();
        Qt.callLater(function() {
            nameField.forceActiveFocus();
            nameField.selectAll();
        });
    }

    function submit() {
        const accountIds = [];
        for (let i = 0; i < accountSelection.count; ++i) {
            const row = accountSelection.get(i);
            if (row.selected)
                accountIds.push(row.accountId);
        }
        const categoryLimits = [];
        for (let j = 0; j < categorySelection.count; ++j) {
            const category = categorySelection.get(j);
            if (!category.selected)
                continue;
            const value = Number(String(category.limitText).replace(",", "."));
            categoryLimits.push({
                categoryId: category.categoryId,
                limitMinor: Number.isFinite(value) && value > 0
                          ? Math.round(value * 100) : 0
            });
        }
        const amount = Number(amountField.text.replace(",", "."));
        const result = controller.saveBudget({
            id: editingId,
            name: nameField.text,
            currency: currencyBox.currentText,
            limitMinor: Number.isFinite(amount) ? Math.round(amount * 100) : 0,
            allAccounts: allAccountsBox.checked,
            accountIds: accountIds,
            allCategories: allCategoriesBox.checked,
            categoryLimits: categoryLimits
        });
        if (!result.ok) {
            formError.text = result.error || "Не удалось сохранить бюджет";
            return;
        }
        close();
    }

    onClosed: editingId = ""

    background: Rectangle {
        HardShadow { visible: !Appearance.desktop;  depth: 6; shadowColor: dialog.accentColor }

        color: dialog.panelColor
        radius: Appearance.desktop ? 0 : 16
        border.width: 1
        border.color: dialog.accentColor
    }

    component Field: StyledTextField {
        neo: true
        implicitWidth: 160
        Layout.minimumWidth: 0
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appOnAccentColor: dialog.panelColor
    }

    component FormCombo: StyledComboBox {
        neo: true
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appHoverColor: (Appearance.desktop ? "#e9e4d8" : "#E4E8F1")
    }

    component FormCheckBox: StyledCheckBox {
        neo: true
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appHoverColor: (Appearance.desktop ? "#e9e4d8" : "#E4E8F1")
        appOnAccentColor: dialog.panelColor
    }

    component ActionButton: StyledButton {
        neo: true
        cornerRadius: 8
        font.weight: Font.DemiBold
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appHoverColor: (Appearance.desktop ? "#e9e4d8" : "#E4E8F1")
        appOnAccentColor: dialog.panelColor
        appErrorColor: dialog.errorColor
    }

    contentItem: EditorialColumnLayout {
        spacing: 0

        EditorialRowLayout {
            Layout.fillWidth: true
            Layout.margins: Appearance.desktop ? 24 : 20
            EditorialDialogTitle {
                ruleVisible: false
                Layout.fillWidth: true
                text: dialog.editingId.length > 0
                    ? "Редактирование бюджета" : "Новый бюджет"
                color: dialog.textColor
                }
            ActionButton { text: "Закрыть"; onClicked: dialog.close() }
        }

        Rectangle { Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; height: 1; color: dialog.accentColor }

        EditorialScrollView {
            topPadding: Appearance.desktop ? 16 : 0
            bottomPadding: Appearance.desktop ? 16 : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            EditorialColumnLayout {
                width: Math.max(0, parent.width - (Appearance.desktop ? 48 : 40))
                x: Appearance.desktop ? 24 : 20
                spacing: 12

                EditorialLabel { text: "Название"; color: dialog.mutedColor }
                Field {
                    id: nameField; objectName: "nameField"
                    Layout.fillWidth: true
                    placeholderText: "Например, общий бюджет"
                    maximumLength: 80
                }

                EditorialRowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.desktop ? 12 : 10
                    EditorialColumnLayout {
                        Layout.fillWidth: true
                        EditorialLabel { text: "Лимит на месяц"; color: dialog.mutedColor }
                        Field {
                            id: amountField; objectName: "amountField"
                            Layout.fillWidth: true
                            placeholderText: "0,00"
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: DoubleValidator { bottom: 0.01; decimals: 2 }
                        }
                    }
                    EditorialColumnLayout {
                        Layout.preferredWidth: Appearance.desktop ? 132 : 130
                        EditorialLabel { text: "Валюта"; color: dialog.mutedColor }
                        FormCombo {
                            id: currencyBox; objectName: "currencyBox"
                            Layout.fillWidth: true
                            implicitHeight: 44
                            model: ["RUB", "USD", "EUR", "CNY"]
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: dialog.lineColor }
                FormCheckBox {
                    id: allAccountsBox; objectName: "allAccountsBox"
                    text: "Учитывать все счета"
                    palette.text: dialog.textColor
                }
                EditorialLabel {
                    visible: !allAccountsBox.checked
                    text: "Выбранные счета"
                    color: dialog.mutedColor
                }
                Repeater {
                    model: accountSelection
                    delegate: FormCheckBox {
                        required property int index
                        required property string label
                        required property bool selected
                        visible: !allAccountsBox.checked
                        text: label
                        checked: selected
                        palette.text: dialog.textColor
                        onToggled: accountSelection.setProperty(index, "selected", checked)
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: dialog.lineColor }
                FormCheckBox {
                    id: allCategoriesBox; objectName: "allCategoriesBox"
                    text: "Учитывать все категории расходов"
                    palette.text: dialog.textColor
                }
                EditorialLabel {
                    Layout.fillWidth: true
                    text: allCategoriesBox.checked
                        ? "Отметьте категории, если хотите задать им отдельные лимиты"
                        : "Отметьте категории, которые входят в бюджет"
                    color: dialog.mutedColor
                    font.pixelSize: Appearance.desktop ? 16 : 14
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: categorySelection
                    delegate: EditorialRowLayout {
                        required property int index
                        required property string label
                        required property bool selected
                        required property string limitText
                        Layout.fillWidth: true
                        FormCheckBox {
                            checked: parent.selected
                            text: parent.label
                            palette.text: dialog.textColor
                            Layout.fillWidth: true
                            onToggled: categorySelection.setProperty(
                                parent.index, "selected", checked)
                        }
                        Field {
                            visible: parent.selected
                            Layout.preferredWidth: 180
                            placeholderText: "Лимит, необязательно"
                            text: parent.limitText
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onTextEdited: categorySelection.setProperty(
                                parent.index, "limitText", text)
                        }
                    }
                }

                EditorialLabel {
                    id: formError; objectName: "formError"
                    Layout.fillWidth: true
                    color: dialog.errorColor
                    font.pixelSize: Appearance.desktop ? 16 : 14
                    wrapMode: Text.WordWrap
                }
                Item { Layout.preferredHeight: 8 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: dialog.lineColor }
        EditorialRowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            Item { Layout.fillWidth: true }
            ActionButton { text: "Отмена"; onClicked: dialog.close() }
            ActionButton {
                text: "Сохранить"
                primary: true
                onClicked: dialog.submit()
            }
        }
    }
}
