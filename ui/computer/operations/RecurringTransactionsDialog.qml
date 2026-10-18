import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

EditorialDialog {
    id: dialog; objectName: "dialog"
    width: Math.min(860, parent ? parent.width - 40 : 860)
    height: Math.min(720, parent ? parent.height - 40 : 720)
    modal: true
    anchors.centerIn: parent
    padding: 0
    closePolicy: Popup.CloseOnEscape

    required property var controller
    property var moneyFormatter
    property color panelColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF8")
    property color softColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF0")
    property color textColor: "#031528"
    property color mutedColor: (Appearance.desktop ? "#59616a" : "#687483")
    property color lineColor: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color accentColor: "#031528"
    property color errorColor: (Appearance.desktop ? "#b84932" : "#B94F48")
    property color successColor: "#3F735F"
    property int pageIndex: 0
    property string editingId: ""
    property date startsOn: new Date()
    property string statusText: ""

    function openManager() {
        pageIndex = 0;
        editingId = "";
        statusText = "";
        open();
    }

    function fiatAccounts() {
        const result = [];
        const accounts = controller.allAccounts;
        for (let i = 0; i < accounts.length; ++i) {
            if (accounts[i].asset === "fiat")
                result.push({
                    label: accounts[i].name + " · " + accounts[i].currency,
                    value: accounts[i].id,
                    currency: accounts[i].currency
                });
        }
        return result;
    }

    function categoryItems(type) {
        const result = [];
        const categories = controller.categories;
        for (let i = 0; i < categories.length; ++i) {
            if (categories[i].type === type)
                result.push(categories[i]);
        }
        return result;
    }

    function indexByValue(model, value) {
        for (let i = 0; i < model.length; ++i)
            if (model[i].value === value)
                return i;
        return model.length > 0 ? 0 : -1;
    }

    function selectAccountCurrency() {
        const items = accountBox.model;
        const index = accountBox.currentIndex;
        if (index >= 0 && index < items.length)
            currencyBox.currentIndex = indexByValue(
                currencyBox.model, items[index].currency);
    }

    function dateFromIso(value) {
        const parts = String(value || "").split("-");
        if (parts.length !== 3)
            return new Date();
        return new Date(Number(parts[0]), Number(parts[1]) - 1,
                        Number(parts[2]), 12, 0, 0, 0);
    }

    function dateToIso(value) {
        const month = value.getMonth() + 1;
        const day = value.getDate();
        return value.getFullYear() + "-"
             + (month < 10 ? "0" : "") + month + "-"
             + (day < 10 ? "0" : "") + day;
    }

    function amountForInput(minor) {
        const value = Math.max(0, Math.round(Number(minor)));
        const whole = Math.floor(value / 100);
        const cents = value % 100;
        return cents === 0 ? String(whole)
                           : String(whole) + ","
                             + (cents < 10 ? "0" : "") + cents;
    }

    function formatAmount(row) {
        return moneyFormatter
            ? moneyFormatter(row.amount, row.currency, false)
            : String(Number(row.amount) / 100) + " " + row.currency;
    }

    function dayItems() {
        const result = [];
        for (let day = 1; day <= 31; ++day)
            result.push({ label: String(day), value: day });
        return result;
    }

    function openForNew() {
        editingId = "";
        nameField.clear();
        amountField.clear();
        typeBox.currentIndex = 1;
        accountBox.model = fiatAccounts();
        accountBox.currentIndex = accountBox.model.length > 0 ? 0 : -1;
        selectAccountCurrency();
        categoryBox.model = categoryItems("expense");
        categoryBox.currentIndex = categoryBox.model.length > 0 ? 0 : -1;
        recurrenceBox.currentIndex = 0;
        weekdayBox.currentIndex = (new Date().getDay() + 6) % 7;
        dayBox.currentIndex = Math.max(0, new Date().getDate() - 1);
        weekBox.currentIndex = 0;
        startsOn = new Date();
        formError.text = "";
        pageIndex = 1;
        Qt.callLater(function() { nameField.forceActiveFocus(); });
    }

    function openForEdit(row) {
        editingId = row.id;
        nameField.text = row.name;
        amountField.text = amountForInput(row.amount);
        typeBox.currentIndex = row.type === "income" ? 0 : 1;
        accountBox.model = fiatAccounts();
        accountBox.currentIndex = indexByValue(accountBox.model, row.accountId);
        currencyBox.currentIndex = indexByValue(currencyBox.model, row.currency);
        categoryBox.model = categoryItems(row.type);
        categoryBox.currentIndex = indexByValue(categoryBox.model, row.categoryId);
        recurrenceBox.currentIndex = row.recurrence === "daily" ? 0
                                   : row.recurrence === "weekly" ? 1
                                   : row.recurrence === "monthly_day" ? 2 : 3;
        weekdayBox.currentIndex = indexByValue(weekdayBox.model, row.weekday);
        dayBox.currentIndex = indexByValue(dayBox.model, row.dayOfMonth);
        weekBox.currentIndex = indexByValue(weekBox.model, row.weekOfMonth);
        startsOn = dateFromIso(row.startsOn);
        formError.text = "";
        pageIndex = 1;
        Qt.callLater(function() { nameField.forceActiveFocus(); });
    }

    function submit() {
        const minor = Math.round(
            (Number(amountField.text.replace(",", ".")) || 0) * 100
        );
        const result = controller.saveScheduledTransaction({
            id: editingId,
            name: nameField.text,
            accountId: accountBox.currentValue || "",
            categoryId: categoryBox.currentValue || "",
            type: typeBox.currentValue,
            amount: minor,
            currency: currencyBox.currentValue,
            recurrence: recurrenceBox.currentValue,
            weekday: weekdayBox.currentValue,
            dayOfMonth: dayBox.currentValue,
            weekOfMonth: weekBox.currentValue,
            startsOn: dateToIso(startsOn)
        });
        if (!result.ok) {
            formError.text = result.error || qsTr("Не удалось сохранить операцию");
            return;
        }
        statusText = editingId.length > 0
                   ? qsTr("Расписание обновлено")
                   : qsTr("Операция запланирована");
        editingId = "";
        pageIndex = 0;
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.ApplicationShortcut
        enabled: dialog.visible && dialog.pageIndex === 1
              && !typeBox.activeFocus && !typeBox.popup.visible
              && !accountBox.activeFocus && !accountBox.popup.visible
              && !categoryBox.activeFocus && !categoryBox.popup.visible
              && !recurrenceBox.activeFocus && !recurrenceBox.popup.visible
              && !weekdayBox.activeFocus && !weekdayBox.popup.visible
              && !dayBox.activeFocus && !dayBox.popup.visible
              && !weekBox.activeFocus && !weekBox.popup.visible
              && !startDateButton.activeFocus
              && !formCancelButton.activeFocus
              && !formSubmitButton.activeFocus
              && !dateDialog.visible
        onActivated: dialog.submit()
    }

    component FormField: StyledTextField {
        neo: true
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
        textRole: "label"
        valueRole: "value"
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appHoverColor: (Appearance.desktop ? "#e9e4d8" : "#E4E8F1")
    }

    component FormButton: StyledButton {
        neo: true
        cornerRadius: 8
        font.weight: Font.DemiBold
        leftPadding: Appearance.desktop ? 16 : 14
        rightPadding: Appearance.desktop ? 16 : 14
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

    background: Rectangle {
        HardShadow { visible: !Appearance.desktop;  depth: 6; shadowColor: dialog.accentColor }

        color: dialog.panelColor
        radius: Appearance.desktop ? 0 : 16
        border.width: 1
        border.color: dialog.accentColor
    }

    contentItem: EditorialColumnLayout {
        spacing: 0

        EditorialRowLayout {
            Layout.fillWidth: true
            Layout.margins: Appearance.desktop ? 24 : 20
            spacing: 12
            FormButton {
                Layout.preferredWidth: 40
                Layout.minimumWidth: 40
                Layout.maximumWidth: 40
                visible: dialog.pageIndex === 1
                text: "‹"
                onClicked: dialog.pageIndex = 0
            }
            EditorialDialogTitle {
                ruleVisible: false
                Layout.fillWidth: true
                text: dialog.pageIndex === 0
                    ? qsTr("Запланированные операции")
                    : dialog.editingId.length > 0
                      ? qsTr("Редактирование расписания")
                      : qsTr("Новая запланированная операция")
                color: dialog.textColor
                }
        }

        Rectangle { Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; height: 1; color: dialog.accentColor }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: dialog.pageIndex

            Item {
                EditorialColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.desktop ? 20 : 18
                    spacing: Appearance.desktop ? 12 : 10

                    EditorialLabel {
                        Layout.fillWidth: true
                        visible: dialog.statusText.length > 0
                        text: dialog.statusText
                        color: dialog.successColor
                    }

                    ListView {
                        id: scheduleList; objectName: "scheduleList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        clip: true
                        model: dialog.controller.scheduledTransactions

                        delegate: Rectangle {
                            HardShadow { visible: !Appearance.desktop;  depth: 4; shadowColor: dialog.accentColor }

                            required property var modelData
                            width: ListView.view.width
                            height: 98
                            radius: Appearance.desktop ? 0 : 12
                            color: dialog.softColor
                            border.width: 1
                            border.color: dialog.accentColor

                            EditorialRowLayout {
                                anchors.fill: parent
                                anchors.margins: Appearance.desktop ? 16 : 13
                                spacing: 12

                                EditorialColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    EditorialLabel {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: dialog.textColor
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    EditorialLabel {
                                        Layout.fillWidth: true
                                        text: modelData.scheduleText
                                            + " · " + qsTr("следующая: %1")
                                                .arg(Qt.formatDate(
                                                    dialog.dateFromIso(modelData.nextDate),
                                                    "dd.MM.yyyy"))
                                        color: dialog.mutedColor
                                        font.pixelSize: Appearance.desktop ? 16 : 14
                                        elide: Text.ElideRight
                                    }
                                    EditorialLabel {
                                        Layout.fillWidth: true
                                        text: modelData.accountName
                                            + " · " + modelData.categoryName
                                        color: dialog.mutedColor
                                        font.pixelSize: Appearance.desktop ? 16 : 14
                                        elide: Text.ElideRight
                                    }
                                }

                                EditorialLabel {
                                    text: (modelData.type === "income" ? "+" : "−")
                                        + dialog.formatAmount(modelData)
                                    color: modelData.type === "income"
                                         ? dialog.successColor : dialog.errorColor
                                    font.pixelSize: Appearance.desktop ? 16 : 14
                                    font.weight: Font.DemiBold
                                }
                                FormButton {
                                    text: qsTr("Изменить")
                                    onClicked: dialog.openForEdit(modelData)
                                }
                                FormButton {
                                    text: qsTr("Удалить")
                                    destructive: true
                                    onClicked: deleteDialog.openFor(modelData)
                                }
                            }
                        }

                        EditorialLabel {
                            anchors.centerIn: parent
                            visible: scheduleList.count === 0
                            text: qsTr("Запланированных операций пока нет")
                            color: dialog.mutedColor
                        }
                    }
                }
            }

            EditorialScrollView {
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                EditorialColumnLayout {
                    width: Math.max(0, parent.width - 40)
                    x: 20
                    spacing: Appearance.desktop ? 12 : 11

                    EditorialLabel { text: qsTr("Название"); color: dialog.mutedColor }
                    FormField {
                        id: nameField; objectName: "nameField"
                        Layout.fillWidth: true
                        placeholderText: qsTr("Например, аренда квартиры")
                    }

                    EditorialRowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.desktop ? 12 : 10
                        EditorialColumnLayout {
                            Layout.fillWidth: true
                            EditorialLabel { text: qsTr("Тип"); color: dialog.mutedColor }
                            FormCombo {
                                id: typeBox; objectName: "typeBox"
                                Layout.fillWidth: true
                                model: [
                                    { label: qsTr("Доход"), value: "income" },
                                    { label: qsTr("Расход"), value: "expense" }
                                ]
                                onActivated: {
                                    categoryBox.model = dialog.categoryItems(currentValue);
                                    categoryBox.currentIndex = categoryBox.model.length > 0
                                                             ? 0 : -1;
                                }
                            }
                        }
                        EditorialColumnLayout {
                            Layout.fillWidth: true
                            EditorialLabel { text: qsTr("Сумма"); color: dialog.mutedColor }
                            FormField {
                                id: amountField; objectName: "amountField"
                                implicitWidth: 160
                                Layout.minimumWidth: 0
                                Layout.fillWidth: true
                                autoScroll: true
                                placeholderText: qsTr("0,00")
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                validator: DoubleValidator {
                                    bottom: 0.01
                                    top: 999999999
                                    decimals: 2
                                }
                            }
                        }
                        EditorialColumnLayout {
                            Layout.preferredWidth: 120
                            EditorialLabel { text: qsTr("Валюта"); color: dialog.mutedColor }
                            FormCombo {
                                id: currencyBox; objectName: "currencyBox"
                                Layout.fillWidth: true
                                model: [
                                    { label: "RUB", value: "RUB" },
                                    { label: "USD", value: "USD" },
                                    { label: "EUR", value: "EUR" },
                                    { label: "CNY", value: "CNY" }
                                ]
                            }
                        }
                    }

                    EditorialLabel { text: qsTr("Счёт"); color: dialog.mutedColor }
                    FormCombo {
                        id: accountBox; objectName: "accountBox"
                        Layout.fillWidth: true
                        onActivated: dialog.selectAccountCurrency()
                    }
                    EditorialLabel { text: qsTr("Категория"); color: dialog.mutedColor }
                    FormCombo { id: categoryBox; objectName: "categoryBox"; Layout.fillWidth: true }

                    EditorialLabel { text: qsTr("Повторение"); color: dialog.mutedColor }
                    FormCombo {
                        id: recurrenceBox; objectName: "recurrenceBox"
                        Layout.fillWidth: true
                        model: [
                            { label: qsTr("Ежедневно"), value: "daily" },
                            { label: qsTr("Каждую неделю"), value: "weekly" },
                            { label: qsTr("Каждый месяц в выбранное число"), value: "monthly_day" },
                            { label: qsTr("Выбранный день недели каждого месяца"), value: "monthly_weekday" }
                        ]
                    }

                    EditorialRowLayout {
                        visible: recurrenceBox.currentValue !== "daily"
                        Layout.fillWidth: true
                        spacing: Appearance.desktop ? 12 : 10
                        EditorialColumnLayout {
                            visible: recurrenceBox.currentValue === "monthly_weekday"
                            Layout.fillWidth: true
                            EditorialLabel { text: qsTr("Неделя месяца"); color: dialog.mutedColor }
                            FormCombo {
                                id: weekBox; objectName: "weekBox"
                                Layout.fillWidth: true
                                model: [
                                    { label: qsTr("Первая"), value: 1 },
                                    { label: qsTr("Вторая"), value: 2 },
                                    { label: qsTr("Третья"), value: 3 },
                                    { label: qsTr("Четвёртая"), value: 4 },
                                    { label: qsTr("Последняя"), value: 5 }
                                ]
                            }
                        }
                        EditorialColumnLayout {
                            visible: recurrenceBox.currentValue === "weekly"
                                  || recurrenceBox.currentValue === "monthly_weekday"
                            Layout.fillWidth: true
                            EditorialLabel { text: qsTr("День недели"); color: dialog.mutedColor }
                            FormCombo {
                                id: weekdayBox; objectName: "weekdayBox"
                                Layout.fillWidth: true
                                model: [
                                    { label: qsTr("Понедельник"), value: 1 },
                                    { label: qsTr("Вторник"), value: 2 },
                                    { label: qsTr("Среда"), value: 3 },
                                    { label: qsTr("Четверг"), value: 4 },
                                    { label: qsTr("Пятница"), value: 5 },
                                    { label: qsTr("Суббота"), value: 6 },
                                    { label: qsTr("Воскресенье"), value: 7 }
                                ]
                            }
                        }
                        EditorialColumnLayout {
                            visible: recurrenceBox.currentValue === "monthly_day"
                            Layout.fillWidth: true
                            EditorialLabel { text: qsTr("Число месяца"); color: dialog.mutedColor }
                            FormCombo {
                                id: dayBox; objectName: "dayBox"
                                Layout.fillWidth: true
                                model: dialog.dayItems()
                            }
                        }
                    }

                    EditorialLabel { text: qsTr("Начать с"); color: dialog.mutedColor }
                    FormButton {
                        id: startDateButton; objectName: "startDateButton"
                        Layout.fillWidth: true
                        text: Qt.formatDate(dialog.startsOn, "dd.MM.yyyy")
                        onClicked: dateDialog.openFor(dialog.startsOn)
                    }

                    EditorialLabel {
                        Layout.fillWidth: true
                        visible: recurrenceBox.currentValue === "monthly_day"
                        text: qsTr("Если выбранного числа нет в месяце, операция будет создана в последний день месяца.")
                        color: dialog.mutedColor
                        font.pixelSize: Appearance.desktop ? 16 : 14
                        wrapMode: Text.WordWrap
                    }
                    EditorialLabel {
                        id: formError; objectName: "formError"
                        Layout.fillWidth: true
                        color: dialog.errorColor
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.preferredHeight: 12 }
                }
            }
        }

        EditorialRowLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 12
            Item { Layout.fillWidth: true }
            FormButton {
                visible: dialog.pageIndex === 0
                text: qsTr("Закрыть")
                onClicked: dialog.close()
            }
            FormButton {
                visible: dialog.pageIndex === 0
                text: qsTr("+ Добавить")
                primary: true
                onClicked: dialog.openForNew()
            }
            FormButton {
                id: formCancelButton; objectName: "formCancelButton"
                visible: dialog.pageIndex === 1
                text: qsTr("Отмена")
                onClicked: dialog.pageIndex = 0
            }
            FormButton {
                id: formSubmitButton; objectName: "formSubmitButton"
                visible: dialog.pageIndex === 1
                text: dialog.editingId.length > 0
                    ? qsTr("Сохранить") : qsTr("Добавить")
                primary: true
                onClicked: dialog.submit()
            }
        }
    }

    EditorialDialog {
        id: deleteDialog; objectName: "deleteDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 440
        modal: true
        padding: Appearance.desktop ? 24 : 22
        property var row: null
        function openFor(value) {
            row = value;
            deleteError.text = "";
            open();
        }
        function confirmDelete() {
            if (row && dialog.controller.deleteScheduledTransaction(row.id)) {
                dialog.statusText = qsTr("Расписание удалено");
                close();
            } else {
                deleteError.text = qsTr("Не удалось удалить расписание");
            }
        }
        Shortcut {
            sequences: ["Return", "Enter"]
            context: Qt.ApplicationShortcut
            enabled: deleteDialog.visible
                  && !deleteCancelButton.activeFocus
                  && !deleteSubmitButton.activeFocus
            onActivated: deleteDialog.confirmDelete()
        }
        background: Rectangle {
            HardShadow { visible: !Appearance.desktop;  depth: 6; shadowColor: dialog.accentColor }

            color: dialog.panelColor
            radius: Appearance.desktop ? 0 : 16
            border.width: 1
            border.color: dialog.accentColor
        }
        contentItem: EditorialDialogForm {
            spacing: Appearance.desktop ? 16 : 13
            EditorialDialogTitle {
                text: qsTr("Удалить расписание?")
                color: dialog.textColor
                }
            EditorialLabel {
                Layout.fillWidth: true
                text: qsTr("Будущие операции больше не будут создаваться. Уже добавленные в историю операции сохранятся.")
                color: dialog.mutedColor
                wrapMode: Text.WordWrap
            }
            EditorialLabel {
                Layout.fillWidth: true
                text: deleteDialog.row ? deleteDialog.row.name : ""
                color: dialog.textColor
                font.weight: Font.DemiBold
            }
            EditorialLabel { id: deleteError; objectName: "deleteError"; color: dialog.errorColor }
            EditorialRowLayout {
                Item { Layout.fillWidth: true }
                FormButton {
                    id: deleteCancelButton; objectName: "deleteCancelButton"
                    text: qsTr("Отмена")
                    onClicked: deleteDialog.close()
                }
                FormButton {
                    id: deleteSubmitButton; objectName: "deleteSubmitButton"
                    text: qsTr("Удалить")
                    destructive: true
                    onClicked: deleteDialog.confirmDelete()
                }
            }
        }
    }

    EditorialDialog {
        id: dateDialog; objectName: "dateDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 400
        modal: true
        padding: 20
        property int displayedMonth: new Date().getMonth()
        property int displayedYear: new Date().getFullYear()
        function openFor(date) {
            displayedMonth = date.getMonth();
            displayedYear = date.getFullYear();
            open();
        }
        function shiftMonth(offset) {
            const shifted = new Date(displayedYear, displayedMonth + offset, 1);
            displayedMonth = shifted.getMonth();
            displayedYear = shifted.getFullYear();
        }
        background: Rectangle {
            HardShadow { visible: !Appearance.desktop;  depth: 6; shadowColor: dialog.accentColor }

            color: dialog.panelColor
            radius: Appearance.desktop ? 0 : 16
            border.width: 1
            border.color: dialog.accentColor
        }
        contentItem: EditorialDialogForm {
            spacing: 12
            EditorialDialogTitle {
                text: qsTr("Дата начала")
                color: dialog.textColor
                }
            EditorialRowLayout {
                Layout.fillWidth: true
                FormButton {
                    Layout.preferredWidth: 40
                    Layout.minimumWidth: 40
                    Layout.maximumWidth: 40
                    text: "‹"
                    onClicked: dateDialog.shiftMonth(-1)
                }
                EditorialLabel {
                    Layout.fillWidth: true
                    text: startCalendar.title
                    color: dialog.textColor
                    horizontalAlignment: Text.AlignHCenter
                    font.weight: Font.DemiBold
                }
                FormButton {
                    Layout.preferredWidth: 40
                    Layout.minimumWidth: 40
                    Layout.maximumWidth: 40
                    text: "›"
                    onClicked: dateDialog.shiftMonth(1)
                }
            }
            DayOfWeekRow {
                spacing: 4
                Layout.fillWidth: true
                locale: Qt.locale(dialog.controller.uiLanguage === "en"
                                  ? "en_US" : "ru_RU")
                delegate: EditorialLabel {
                    required property string shortName
                    text: shortName
                    color: dialog.mutedColor
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            MonthGrid {
                spacing: 4
                id: startCalendar; objectName: "startCalendar"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0, (width - spacing * 6) / 7 * 6 + spacing * 5)
                month: dateDialog.displayedMonth
                year: dateDialog.displayedYear
                locale: Qt.locale(dialog.controller.uiLanguage === "en"
                                  ? "en_US" : "ru_RU")
                delegate: Button {
                    id: calendarDay; objectName: "calendarDay"
                    required property var model
                    flat: true
                    opacity: model.month === startCalendar.month ? 1 : 0.42
                    onClicked: {
                        dialog.startsOn = new Date(
                            model.date.getFullYear(), model.date.getMonth(),
                            model.date.getDate(), 12, 0, 0, 0);
                        dateDialog.close();
                    }
                    contentItem: EditorialLabel {
                        text: calendarDay.model.day
                        color: dialog.textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {


                        radius: Appearance.desktop ? 0 : 8
                        color: calendarDay.hovered
                             ? dialog.softColor : "transparent"
                    }
                }
            }
            EditorialRowLayout {
                Item { Layout.fillWidth: true }
                FormButton {
                    text: qsTr("Сегодня")
                    onClicked: {
                        dialog.startsOn = new Date();
                        dateDialog.close();
                    }
                }
                FormButton {
                    text: qsTr("Отмена")
                    onClicked: dateDialog.close()
                }
            }
        }
    }
}
