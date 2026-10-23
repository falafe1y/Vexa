import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

EditorialDialog {
    id: dialog; objectName: "dialog"
    property var controller
    property color panelColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF8")
    property color softColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF0")
    property color textColor: "#031528"
    property color mutedColor: (Appearance.desktop ? "#59616a" : "#687483")
    property color lineColor: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color accentColor: "#031528"
    property color hoverColor: (Appearance.desktop ? "#e9e4d8" : "#E4E8F1")
    property color errorColor: (Appearance.desktop ? "#b84932" : "#B94F48")
    property int selectedResult: -1
    property string localError: ""
    property string fixedAccountId: ""
    property string editingPositionId: ""
    property var editingInstrument: null
    property bool showingCurrentInstrument: false
    readonly property bool manualInstrument: sourceBox.currentIndex === 1
    readonly property var selectedInstrument: showingCurrentInstrument ? editingInstrument
        : controller && selectedResult >= 0 && selectedResult < controller.investmentSearchResults.length
          ? controller.investmentSearchResults[selectedResult] : null
    readonly property int instrumentType: manualInstrument ? typeBox.currentValue
        : selectedInstrument ? selectedInstrument.type : -1
    readonly property string pricing: selectedInstrument ? selectedInstrument.pricing : "manual"
    readonly property bool derivative: instrumentType === 9 || instrumentType === 10
    readonly property bool margined: pricing === "future" || pricing === "margined_option"
    readonly property var selectedAccount: accountBox.currentIndex >= 0 && controller
        ? controller.investmentAccounts[accountBox.currentIndex] : null
    readonly property string accountCurrency: selectedAccount ? selectedAccount.currency : "RUB"

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - 32 : 680, 680)
    height: Math.min(parent ? parent.height - 32 : 820, 820)
    modal: true
    title: editingPositionId ? "Редактирование позиции" : "Добавить инвестиционный инструмент"
    standardButtons: Dialog.NoButton
    header: EditorialDialogTitle {
        text: dialog.title; color: dialog.textColor;  leftPadding: dialog.leftPadding; rightPadding: dialog.rightPadding; topPadding: dialog.topPadding
        wrapMode: Text.WordWrap
    }
    background: Rectangle {
        color: dialog.panelColor; radius: Appearance.desktop ? 0 : 16; border.width: 1; border.color: dialog.accentColor
        HardShadow { visible: !Appearance.desktop;  depth: 6; shadowColor: dialog.accentColor }
    }

    function resetFields() {
        localError = ""; selectedResult = -1; searchField.text = ""; quantityField.text = "";
        averagePriceField.text = ""; nameField.text = ""; symbolField.text = ""; manualValueField.text = "";
        referencePriceField.text = ""; referenceDateField.text = ""; marginField.text = "0";
        adjustmentField.text = "0"; fxField.text = ""; cashField.text = ""; costField.text = ""; feeField.text = ""; taxField.text = "";
        sourceBox.currentIndex = 0; directionBox.currentIndex = 0; entryBox.currentIndex = 0;
        optionSchemeBox.currentIndex = 0; rightBox.currentIndex = 0; strikeField.text = ""; maturityField.text = ""; underlyingField.text = "";
        manualCheck.checked = false; accountBox.currentIndex = -1;
    }
    function chooseAccount(id) {
        if (!controller) return;
        const accounts = controller.investmentAccounts;
        for (let i = 0; i < accounts.length; ++i) if (!id || accounts[i].id === id) { accountBox.currentIndex = i; break; }
    }
    function openForNewPosition(accountId) {
        editingPositionId = ""; editingInstrument = null; showingCurrentInstrument = false;
        fixedAccountId = accountId || ""; resetFields(); chooseAccount(fixedAccountId); open();
        Qt.callLater(function() { searchField.forceActiveFocus(); });
    }
    function openForEdit(position) {
        if (!position) return;
        resetFields(); editingPositionId = position.id; editingInstrument = Object.assign({}, position, {type: position.instrumentType === undefined ? position.type : position.instrumentType});
        showingCurrentInstrument = true; fixedAccountId = ""; selectedResult = 0;
        chooseAccount(position.accountId); searchField.text = position.symbol;
        quantityField.text = position.quantityText; averagePriceField.text = position.averagePriceText;
        costField.text = position.costBasisText || "";
        directionBox.currentIndex = position.direction === -1 ? 1 : 0;
        manualCheck.checked = position.manualValuation; manualValueField.text = position.manualValueText || "";
        referencePriceField.text = position.referencePriceText || "";
        referenceDateField.text = position.referenceDate ? Qt.formatDateTime(new Date(position.referenceDate), "dd.MM.yyyy HH:mm:ss") : "";
        marginField.text = position.blockedMarginText || "0"; adjustmentField.text = position.adjustmentText || "0";
        fxField.text = position.fxRateText || ""; open();
    }
    // The money of a purchase is quantity times price; a bond's price is a percent of its face value,
    // so bonds and derivatives keep the money typed by hand
    function updateCash() {
        if (dialog.derivative || dialog.instrumentType === 2)
            return;
        const quantity = Number(String(quantityField.text).replace(",", "."));
        const price = Number(String(averagePriceField.text).replace(",", "."));
        cashField.text = quantity > 0 && price > 0 ? (-quantity * price).toFixed(2) : "";
    }

    function submit() {
        const result = controller.saveInvestmentPosition({
            id: editingPositionId, accountId: accountBox.currentValue,
            searchIndex: manualInstrument ? -2 : showingCurrentInstrument ? -1 : selectedResult,
            instrumentType: typeBox.currentValue, name: nameField.text, symbol: symbolField.text,
            quantity: quantityField.text, averagePrice: averagePriceField.text,
            direction: derivative && directionBox.currentIndex === 1 ? -1 : 1,
            manualValuation: manualInstrument || manualCheck.checked, manualValue: manualValueField.text,
            referencePrice: referencePriceField.text, referenceDate: referenceDateField.text,
            blockedMargin: marginField.text, adjustment: adjustmentField.text, fxRate: fxField.text,
            purchase: !editingPositionId && entryBox.currentIndex === 1, cashAmount: cashField.text,
            costBasis: costField.visible ? costField.text : "", fee: feeField.visible ? feeField.text : "", tax: taxField.visible ? taxField.text : "",
            optionPricing: optionSchemeBox.currentIndex === 1 ? "margined_option" : "premium_option",
            optionRight: rightBox.currentIndex === 1 ? "P" : "C", strike: strikeField.text,
            maturity: maturityField.text, underlying: underlyingField.text
        });
        if (result.ok) close(); else localError = result.error || "Не удалось сохранить позицию";
    }
    onClosed: { editingPositionId = ""; editingInstrument = null; showingCurrentInstrument = false; fixedAccountId = ""; }
    component FormField: StyledTextField {
        Layout.minimumWidth: 0
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
        Layout.minimumWidth: 0
        neo: true
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appHoverColor: dialog.hoverColor
    }

    component FormButton: StyledButton {
        neo: true
        cornerRadius: 8
        font.weight: Font.DemiBold
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appHoverColor: dialog.hoverColor
        appOnAccentColor: dialog.panelColor
        appErrorColor: dialog.errorColor
    }


    contentItem: EditorialColumnLayout {
        spacing: 16
        EditorialScrollView {
            id: positionScroll; objectName: "positionScroll"
            contentWidth: availableWidth
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            EditorialColumnLayout {
                width: positionScroll.availableWidth; spacing: 8
                EditorialLabel { text: "Брокерский счёт"; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                FormCombo {
                    id: accountBox; objectName: "accountBox"; Layout.fillWidth: true; model: dialog.controller ? dialog.controller.investmentAccounts : []
                    textRole: "name"; valueRole: "id"; enabled: !dialog.fixedAccountId && !(dialog.editingInstrument && dialog.editingInstrument.hasOperations)
                }
                EditorialLabel {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                    text: "Остаток брокерского счёта — только деньги, включая заблокированное обеспечение. Стоимость позиций программа прибавит отдельно."
                }
                EditorialLabel {
                    Layout.fillWidth: true; visible: !!dialog.selectedAccount; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                    text: dialog.selectedAccount ? "Деньги: %1 · заблокировано: %2 · свободно: %3 %4"
                        .arg(Number(dialog.selectedAccount.cashMinor / 100).toLocaleString(Qt.locale("ru_RU"), "f", 2))
                        .arg(Number(dialog.selectedAccount.blockedMarginMinor / 100).toLocaleString(Qt.locale("ru_RU"), "f", 2))
                        .arg(Number(dialog.selectedAccount.freeCashMinor / 100).toLocaleString(Qt.locale("ru_RU"), "f", 2)).arg(dialog.accountCurrency) : ""
                }
                FormCombo {
                    id: sourceBox; objectName: "sourceBox"; Layout.fillWidth: true; visible: !dialog.editingPositionId
                    model: ["Найти на бирже", "Добавить с ручной оценкой"]
                    onActivated: { dialog.localError = ""; if (currentIndex === 1) manualCheck.checked = true; }
                }
                EditorialRowLayout {
                    Layout.fillWidth: true; visible: !dialog.manualInstrument
                    FormField { id: searchField; objectName: "searchField"; Layout.fillWidth: true; placeholderText: "Название, обозначение или ISIN"; onAccepted: searchButton.clicked() }
                    FormButton {
                        id: searchButton; objectName: "searchButton"; text: dialog.controller && dialog.controller.investmentSearchBusy ? "Ищем…" : "Найти"
                        enabled: dialog.controller && !dialog.controller.investmentSearchBusy && searchField.text.trim().length >= 2
                            && !(dialog.editingInstrument && dialog.editingInstrument.hasOperations)
                        onClicked: { dialog.showingCurrentInstrument = false; dialog.selectedResult = -1; dialog.localError = "";
                            dialog.controller.searchInvestmentInstruments(searchField.text); }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 180; visible: !dialog.manualInstrument
                    color: dialog.softColor; radius: Appearance.desktop ? 0 : 12; border.width: 1; border.color: dialog.lineColor
                    ListView {
                        anchors.fill: parent; anchors.margins: 8; clip: true; spacing: 4
                        model: dialog.showingCurrentInstrument ? [dialog.editingInstrument] : dialog.controller ? dialog.controller.investmentSearchResults : []
                        delegate: Rectangle {
                            required property var modelData; required property int index
                            width: ListView.view.width; height: 60; radius: Appearance.desktop ? 0 : 8
                            color: index === dialog.selectedResult ? dialog.hoverColor : "transparent"
                            Column {
                                anchors.fill: parent; anchors.margins: 8; spacing: 4
                                EditorialLabel { width: parent.width; text: modelData.symbol + " · " + modelData.name; color: dialog.textColor; font.pixelSize: Appearance.desktop ? 16 : 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                EditorialLabel { width: parent.width; text: modelData.typeName + (modelData.hasPrice ? " · " + modelData.priceText + (modelData.type === 2 ? "%" : modelData.type >= 9 ? " " + "пункт." : " " + modelData.currency) : ""); color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14; elide: Text.ElideRight }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !dialog.showingCurrentInstrument && !dialog.controller.investmentQuoteBusy
                                onClicked: { dialog.selectedResult = index; dialog.localError = ""; manualCheck.checked = false;
                                    referencePriceField.text = ""; referenceDateField.text = ""; averagePriceField.text = "";
                                    dialog.controller.selectInvestmentSearchResult(index); }
                            }
                        }
                        EditorialLabel { anchors.centerIn: parent; visible: parent.count === 0; text: "Акции, облигации, фонды, металлы, валюты и контракты"; color: dialog.mutedColor; width: parent.width - 24; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
                    }
                }
                FormCombo {
                    id: typeBox; objectName: "typeBox"; Layout.fillWidth: true; visible: dialog.manualInstrument
                    textRole: "name"; valueRole: "value"
                    model: [ {name: "Акция", value: 0}, {name: "Привилегированная акция", value: 5},
                        {name: "Депозитарная расписка", value: 6}, {name: "Биржевой фонд", value: 1},
                        {name: "Пай ПИФ", value: 3}, {name: "Облигация", value: 2},
                        {name: "Драгоценный металл", value: 7}, {name: "Валюта", value: 8},
                        {name: "Фьючерс", value: 9}, {name: "Опцион", value: 10}, {name: "Другой инструмент", value: 4} ]
                }
                FormField { id: nameField; objectName: "nameField"; Layout.fillWidth: true; visible: dialog.manualInstrument; placeholderText: "Название инструмента" }
                FormField { id: symbolField; objectName: "symbolField"; Layout.fillWidth: true; visible: dialog.manualInstrument; placeholderText: "Обозначение инструмента" }
                FormCombo { id: optionSchemeBox; objectName: "optionSchemeBox"; Layout.fillWidth: true; visible: dialog.manualInstrument && dialog.instrumentType === 10; model: ["Премиальный опцион", "Маржируемый опцион"] }
                FormCombo { id: rightBox; objectName: "rightBox"; Layout.fillWidth: true; visible: dialog.manualInstrument && dialog.instrumentType === 10; model: ["Право покупки", "Право продажи"] }
                FormField { id: strikeField; objectName: "strikeField"; Layout.fillWidth: true; visible: dialog.manualInstrument && dialog.instrumentType === 10; placeholderText: "Цена исполнения" }
                FormField { id: underlyingField; objectName: "underlyingField"; Layout.fillWidth: true; visible: dialog.manualInstrument && dialog.derivative; placeholderText: "Базовый актив" }
                FormField { id: maturityField; objectName: "maturityField"; Layout.fillWidth: true; visible: dialog.manualInstrument && dialog.derivative; placeholderText: "Дата исполнения, дд.мм.гггг" }
                EditorialLabel {
                    Layout.fillWidth: true; visible: !!dialog.selectedInstrument; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                    text: !dialog.selectedInstrument ? "" : dialog.instrumentType === 2
                        ? "Цена: %1% · текущий номинал: %2 · НКД: %3 %4".arg(dialog.selectedInstrument.priceText || "—").arg(dialog.selectedInstrument.faceValueText || "—").arg(dialog.selectedInstrument.accruedInterestText || "—").arg(dialog.selectedInstrument.quoteCurrency || "")
                        : dialog.derivative
                          ? "Базовый актив: %1 · исполнение: %2 · шаг: %3 · стоимость шага: %4 %5"
                              .arg(dialog.selectedInstrument.underlying || "—").arg(dialog.selectedInstrument.maturity || "—")
                              .arg(dialog.selectedInstrument.priceStepText || "—").arg(dialog.selectedInstrument.stepValueText || "—").arg(dialog.selectedInstrument.quoteCurrency || "")
                          : "Количество указывается в единицах актива, а не в лотах. Лот: %1.".arg(dialog.selectedInstrument.lotSizeText || "1")
                }
                EditorialLabel {
                    Layout.fillWidth: true; visible: dialog.instrumentType === 10 && !!dialog.selectedInstrument; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                    text: !dialog.selectedInstrument ? "" : (dialog.selectedInstrument.optionRight === "C" ? "Право покупки" : dialog.selectedInstrument.optionRight === "P" ? "Право продажи" : "Право не определено")
                        + " · цена исполнения: %1 · %2".arg(dialog.selectedInstrument.strikeText || "—")
                          .arg(dialog.pricing === "premium_option" ? "Премиальный опцион" : dialog.pricing === "margined_option" ? "Маржируемый опцион" : "Расчёт по ручной оценке")
                }
                EditorialLabel { text: "Количество (%1)".arg(dialog.selectedInstrument ? dialog.selectedInstrument.quantityUnit : dialog.instrumentType === 7 ? "г" : dialog.derivative ? "контрактов" : "единиц"); color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                EditorialRowLayout {
                    Layout.fillWidth: true
                    FormField { id: quantityField; objectName: "quantityField"; Layout.fillWidth: true; placeholderText: "Количество"; inputMethodHints: Qt.ImhFormattedNumbersOnly; onTextEdited: dialog.updateCash() }
                    FormField { id: averagePriceField; objectName: "averagePriceField"; Layout.fillWidth: true; placeholderText: dialog.instrumentType === 2 ? "Средняя цена покупки, %" : "Средняя цена покупки"; onTextEdited: dialog.updateCash(); inputMethodHints: Qt.ImhFormattedNumbersOnly }
                }
                FormCombo { id: directionBox; objectName: "directionBox"; Layout.fillWidth: true; visible: dialog.derivative; model: ["Купленная позиция", "Проданная позиция"] }
                StyledCheckBox {
                    id: manualCheck; objectName: "manualCheck"; Layout.fillWidth: true; Layout.minimumWidth: 0; visible: !dialog.manualInstrument; text: "Указать стоимость позиции вручную"
                    appTextColor: dialog.textColor; appSoftColor: dialog.softColor; appLineColor: dialog.lineColor; appAccentColor: dialog.accentColor
                }
                EditorialLabel {
                    Layout.fillWidth: true; visible: !!dialog.selectedInstrument && dialog.derivative && dialog.pricing === "manual"
                    text: "Особые условия расчёта: используйте ручную оценку по данным брокера."
                    wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                }
                FormField {
                    id: manualValueField; objectName: "manualValueField"; Layout.fillWidth: true; visible: dialog.manualInstrument || manualCheck.checked
                    placeholderText: "Стоимость всей позиции, %1".arg(dialog.accountCurrency); inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
                EditorialLabel {
                    Layout.fillWidth: true; visible: dialog.manualInstrument || manualCheck.checked; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                    text: dialog.derivative ? "Укажите только ещё не включённый в деньги результат или обязательство со знаком. Для премиального опциона — его текущую стоимость со знаком."
                        : "Укажите общую стоимость актива, для облигаций — с НКД. Деньги на счёте сюда не включаются."
                }
                EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; visible: dialog.margined && !manualCheck.checked; text: "Последний проведённый расчёт или открытие позиции"; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                EditorialRowLayout {
                    Layout.fillWidth: true; visible: dialog.margined && !manualCheck.checked
                    FormField { id: referencePriceField; objectName: "referencePriceField"; Layout.fillWidth: true; placeholderText: "Расчётная цена" }
                    FormField { id: referenceDateField; objectName: "referenceDateField"; Layout.fillWidth: true; placeholderText: "дд.мм.гггг чч:мм:сс" }
                }
                EditorialLabel {
                    Layout.fillWidth: true; visible: dialog.margined && !manualCheck.checked; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                    text: "Прибыль до указанного расчёта уже должна находиться в денежном остатке. В капитал добавится только изменение после него."
                }
                EditorialRowLayout {
                    Layout.fillWidth: true; visible: dialog.derivative
                    FormField { id: marginField; objectName: "marginField"; Layout.fillWidth: true; placeholderText: "Заблокировано, %1".arg(dialog.accountCurrency) }
                    FormField { id: adjustmentField; objectName: "adjustmentField"; Layout.fillWidth: true; placeholderText: "Ещё не проведённая поправка, %1".arg(dialog.accountCurrency) }
                }
                EditorialLabel { visible: dialog.derivative; text: "Обеспечение входит в деньги и повторно к капиталу не прибавляется."; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                FormField {
                    id: fxField; objectName: "fxField"; Layout.fillWidth: true; visible: !dialog.manualInstrument && !manualCheck.checked && !!dialog.selectedInstrument && dialog.selectedInstrument.quoteCurrency !== dialog.accountCurrency
                    placeholderText: "Курс %1 → %2 (пусто — автоматически)".arg(dialog.selectedInstrument ? dialog.selectedInstrument.quoteCurrency : "").arg(dialog.accountCurrency)
                }
                FormCombo { id: entryBox; objectName: "entryBox"; Layout.fillWidth: true; visible: !dialog.editingPositionId; model: ["Добавить уже имеющуюся позицию", "Записать новую сделку и движение денег"] }
                FormField { id: cashField; objectName: "cashField"; Layout.fillWidth: true; readOnly: !dialog.derivative && dialog.instrumentType !== 2; visible: !dialog.editingPositionId && entryBox.currentIndex === 1; placeholderText: "Изменение денег со знаком, %1".arg(dialog.accountCurrency) }
                FormField { id: costField; objectName: "costField"; Layout.fillWidth: true; visible: !dialog.derivative && (!!dialog.editingPositionId || entryBox.currentIndex === 0); placeholderText: "Стоимость приобретения всей позиции с комиссиями, %1 (если известна)".arg(dialog.accountCurrency) }
                EditorialLabel { Layout.fillWidth: true; visible: costField.visible; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14; text: "Указанная сумма имеет приоритет. Для акций, фондов, металлов и валют в валюте счёта начальные затраты рассчитываются из количества и средней цены покупки. Комиссии добавьте в эту сумму, если они не включены в среднюю цену. Для облигаций и другой валюты укажите фактические затраты. При исправлении остатка проверьте сумму; очистка известной стоимости делает её неизвестной." }
                FormField { id: feeField; objectName: "feeField"; Layout.fillWidth: true; visible: !dialog.editingPositionId && entryBox.currentIndex === 1; placeholderText: "Комиссия внутри указанного движения денег (необязательно)" }
                FormField { id: taxField; objectName: "taxField"; Layout.fillWidth: true; visible: feeField.visible; placeholderText: "Удержания / налог внутри движения денег (необязательно)" }
                EditorialLabel { Layout.fillWidth: true; visible: !dialog.editingPositionId; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14; text: entryBox.currentIndex === 0 ? "Деньги не изменятся: используйте этот режим для переноса текущего портфеля." : "Укажите фактическую сумму с комиссиями: расход со знаком минус, поступление со знаком плюс." }
            }
        }
        EditorialLabel {
            Layout.fillWidth: true; visible: text.length > 0; text: dialog.localError || (dialog.controller ? dialog.controller.investmentLastError : "")
            color: dialog.errorColor; wrapMode: Text.WordWrap; font.pixelSize: Appearance.desktop ? 16 : 14
        }
        EditorialRowLayout {
            Layout.fillWidth: true; Item { Layout.fillWidth: true }
            FormButton { id: cancelButton; objectName: "cancelButton"; text: "Отмена"; onClicked: dialog.close() }
            FormButton { id: saveButton; objectName: "saveButton"; primary: true; text: dialog.editingPositionId ? "Сохранить" : "Добавить"
                enabled: dialog.controller && !dialog.controller.investmentQuoteBusy && accountBox.currentIndex >= 0
                    && (dialog.manualInstrument || dialog.selectedResult >= 0)
                onClicked: dialog.submit() }
        }
    }
}
