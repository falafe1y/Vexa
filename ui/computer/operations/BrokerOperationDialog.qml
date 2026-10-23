import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

// Operations on a brokerage account: buy an instrument, sell one that is already held,
// or move free money to and from fiat or a deposit.
EditorialDialog {
    id: dialog; objectName: "dialog"
    property var controller
    property string accountId: ""
    property string mode: ""
    property color panelColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF8")
    property color softColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF0")
    property color textColor: "#031528"
    property color mutedColor: (Appearance.desktop ? "#59616a" : "#687483")
    property color lineColor: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color accentColor: "#031528"
    property color hoverColor: (Appearance.desktop ? "#e9e4d8" : "#E4E8F1")
    property color errorColor: (Appearance.desktop ? "#b84932" : "#B94F48")
    property string localError: ""
    property int searchResultIndex: -1
    // Which of a price per unit and a sum was typed last: the other one follows it
    property string buyLinkedBy: "price"
    property string sellLinkedBy: "price"
    // The instrument the price field was filled from: a price typed for it is not overwritten by the quote
    property string quotedInstrumentId: ""
    // A bond is quoted in percent of its face value; the face value comes with the instrument terms (0 otherwise)
    readonly property real selectedFaceRub: dialog.selectedInstrument && dialog.selectedInstrument.type === 2
        ? (dialog.selectedInstrument.faceValueMicros || 0) / 1000000 : 0
    readonly property bool percentPrice: selectedFaceRub > 0
    onSelectedInstrumentChanged: dialog.fillPriceFromQuote()

    readonly property var account: {
        const accounts = controller ? controller.investmentAccounts : [];
        for (let i = 0; i < accounts.length; ++i)
            if (accounts[i].id === accountId)
                return accounts[i];
        return null;
    }
    readonly property string accountCurrency: account ? account.currency : "RUB"
    readonly property var selectedInstrument: controller && searchResultIndex >= 0
        && searchResultIndex < controller.investmentSearchResults.length
        ? controller.investmentSearchResults[searchResultIndex] : null
    readonly property bool manualInstrument: sourceBox.currentIndex === 1
    readonly property bool derivativeSelected: !!selectedInstrument
        && (selectedInstrument.type === 9 || selectedInstrument.type === 10)
    readonly property bool busy: !controller || controller.investmentQuoteBusy

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - 32 : 640, 640)
    height: Math.min(parent ? parent.height - 32 : 760, 760)
    modal: true
    title: "Операция по брокерскому счёту"
    standardButtons: Dialog.NoButton
    header: EditorialDialogTitle {
        text: dialog.title; color: dialog.textColor;  leftPadding: dialog.leftPadding; rightPadding: dialog.rightPadding; topPadding: dialog.topPadding
        wrapMode: Text.WordWrap
    }
    background: Rectangle {
        color: dialog.panelColor; radius: Appearance.desktop ? 0 : 16; border.width: 1; border.color: dialog.accentColor
        HardShadow { visible: !Appearance.desktop;  depth: 6; shadowColor: dialog.accentColor }
    }

    function parseAmount(text) {
        const cleaned = String(text || "").replace(/\s/g, "").replace(",", ".");
        const value = Number(cleaned);
        return cleaned.length > 0 && isFinite(value) ? value : NaN;
    }

    // "" for an empty field, "invalid" for a wrong number, otherwise the number as text
    function optionalAmount(text) {
        if (String(text || "").trim().length === 0)
            return "";
        const value = parseAmount(text);
        return value >= 0 ? String(value) : "invalid";
    }

    // Accepts дд.мм.гггг, дд.мм.гггг чч:мм and дд.мм.гггг чч:мм:сс; returns null for anything else
    function parseDate(text) {
        const match = /^\s*(\d{1,2})\.(\d{1,2})\.(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?\s*$/.exec(String(text || ""));
        if (!match)
            return null;
        const date = new Date(Number(match[3]), Number(match[2]) - 1, Number(match[1]),
                              Number(match[4] || 0), Number(match[5] || 0), Number(match[6] || 0));
        return date.getDate() === Number(match[1]) ? date : null;
    }

    function money(minor) {
        return Number(minor / 100).toLocaleString(Qt.locale("ru_RU"), "f", 2);
    }

    // A price per unit in roubles, and back: a bond's price is a percent of its face value
    function costOfUnit(price, face) {
        return face > 0 ? price * face / 100 : price;
    }
    function priceOfUnit(cost, face) {
        return face > 0 ? cost * 100 / face : cost;
    }
    function fixedPrice(value) {
        return String(Number(value.toFixed(6)));
    }

    // A commission typed in roubles or in percent of the sum, in minor units; an empty field is no commission
    function commissionMinor(text, percent, sumMinor) {
        if (String(text || "").trim().length === 0)
            return 0;
        const value = parseAmount(text);
        if (!(value >= 0) || (percent && value > 100))
            return NaN;
        return percent ? Math.round(sumMinor * value / 100) : Math.round(value * 100);
    }

    // The price per unit starts at the last quote of the chosen instrument; a price the user has typed stays
    function fillPriceFromQuote() {
        const instrument = dialog.selectedInstrument;
        const quote = instrument ? (instrument.priceMicros || 0) / 1000000 : 0;
        if (!(quote > 0))
            return;
        if (instrument.id === dialog.quotedInstrumentId && priceField.text.trim().length > 0)
            return;
        dialog.quotedInstrumentId = instrument.id;
        dialog.buyLinkedBy = "price";
        priceField.text = fixedPrice(quote);
        dialog.relinkBuy();
    }

    // The sum is quantity times price: a typed price sets the sum, a typed sum sets the price
    function relinkBuy() {
        const quantity = parseAmount(quantityField.text);
        if (!(quantity > 0))
            return;
        if (dialog.buyLinkedBy === "price") {
            const price = parseAmount(priceField.text);
            if (price > 0)
                cashField.text = (quantity * costOfUnit(price, dialog.selectedFaceRub)).toFixed(2);
        } else {
            const sum = parseAmount(cashField.text);
            if (sum > 0)
                priceField.text = fixedPrice(priceOfUnit(sum / quantity, dialog.selectedFaceRub));
        }
    }
    function relinkSell() {
        const quantity = parseAmount(sellQuantityField.text);
        if (!(quantity > 0))
            return;
        const face = dialog.saleFaceRub();
        if (dialog.sellLinkedBy === "price") {
            const price = parseAmount(sellPriceField.text);
            if (price > 0)
                sellCashField.text = (quantity * costOfUnit(price, face)).toFixed(2);
        } else {
            const sum = parseAmount(sellCashField.text);
            if (sum > 0)
                sellPriceField.text = fixedPrice(priceOfUnit(sum / quantity, face));
        }
    }
    // Face value of the position chosen for a sale; 0 unless that position is a bond
    function saleFaceRub() {
        const positions = positionsForSale();
        const position = positionBox.currentIndex >= 0 ? positions[positionBox.currentIndex] : null;
        return position ? position.face : 0;
    }

    function fail(message) {
        return {ok: false, error: message};
    }

    function resetFields() {
        localError = ""; searchResultIndex = -1; searchField.text = "";
        sourceBox.currentIndex = 0; typeBox.currentIndex = 0; nameField.text = ""; symbolField.text = "";
        quantityField.text = ""; priceField.text = ""; manualValueField.text = ""; cashField.text = "";
        feeField.text = ""; chargeAmountField.text = ""; chargeKindBox.currentIndex = 0;
        positionBox.currentIndex = 0; sellQuantityField.text = ""; sellPriceField.text = ""; sellCashField.text = "";
        sellFeeField.text = ""; sellTaxField.text = "";
        directionBox.currentIndex = 0; counterpartBox.currentIndex = 0; transferAmountField.text = "";
        descriptionField.text = ""; dateField.text = Qt.formatDateTime(new Date(), "dd.MM.yyyy HH:mm:ss");
        fundingAmountField.text = ""; fundingBox.currentIndex = -1;
        feeUnitBox.currentIndex = 0; sellFeeUnitBox.currentIndex = 0;
        buyLinkedBy = "price"; sellLinkedBy = "price";
        quotedInstrumentId = "";
    }

    function openFor(id) {
        accountId = id; mode = ""; resetFields(); open();
    }

    function chooseMode(value) {
        localError = ""; mode = value;
    }

    // Fiat and deposit accounts that money can move to or from
    function counterparts() {
        const rows = controller ? controller.allAccounts : [];
        const result = [];
        for (let i = 0; i < rows.length; ++i) {
            const row = rows[i];
            if (row.id === accountId || row.type === "brokerage")
                continue;
            if (row.asset === "fiat" || row.type === "deposit")
                result.push({name: row.name + " · " + row.currency, id: row.id});
        }
        return result;
    }

    // Held positions of this brokerage account that can be sold here (derivatives are closed from the position list)
    function positionsForSale() {
        const rows = controller ? controller.investmentPositions : [];
        const result = [];
        for (let i = 0; i < rows.length; ++i) {
            const row = rows[i];
            if (row.accountId !== accountId || row.type === 9 || row.type === 10)
                continue;
            result.push({name: row.symbol + " · " + row.name + " · " + row.quantityText, id: row.id,
                         held: parseAmount(row.quantityText), heldText: row.quantityText,
                         face: row.type === 2 ? (row.faceValueMicros || 0) / 1000000 : 0});
        }
        return result;
    }

    function selectedSaleHeldText() {
        const positions = positionsForSale();
        const position = positionBox.currentIndex >= 0 ? positions[positionBox.currentIndex] : null;
        return position ? position.heldText : "";
    }

    function heldPositionId(instrumentId) {
        const rows = controller ? controller.investmentPositions : [];
        for (let i = 0; i < rows.length; ++i)
            if (rows[i].accountId === accountId && rows[i].instrumentId === instrumentId)
                return rows[i].id;
        return "";
    }

    // How much free money a purchase still lacks; the other accounts are not involved until the user picks one
    function purchaseShortfallMinor() {
        if (mode !== "buy" || !account)
            return 0;
        const need = Math.round(parseAmount(cashField.text) * 100);
        if (!(need > 0))
            return 0;
        return Math.max(0, need - account.freeNowMinor);
    }

    // Accounts that can pay for a purchase: fiat and deposit accounts in the same currency with money on them
    function fundingSources() {
        const rows = controller ? controller.allAccounts : [];
        const result = [];
        for (let i = 0; i < rows.length; ++i) {
            const row = rows[i];
            if (row.id === accountId || row.type === "brokerage" || row.currency !== accountCurrency)
                continue;
            // The money that is there now: the balance of a period filter is not the one a transfer needs
            if ((row.asset === "fiat" || row.type === "deposit") && row.currentBalanceMinor > 0)
                result.push({name: row.name + " · " + money(row.currentBalanceMinor) + " " + row.currency,
                             id: row.id, balanceMinor: row.currentBalanceMinor});
        }
        return result;
    }

    // Problems of the purchase form; checked before any money moves
    function buyInputError() {
        const quantity = parseAmount(quantityField.text);
        const cash = parseAmount(cashField.text);
        if (!(quantity > 0))
            return "Укажите количество больше нуля";
        if (!(cash > 0))
            return "Укажите цену покупки или сумму покупки";
        if (isNaN(commissionMinor(feeField.text, feeUnitBox.currentIndex === 1, Math.round(cash * 100))))
            return "Комиссия должна быть неотрицательным числом";
        if (manualInstrument) {
            if (!nameField.text.trim() || !symbolField.text.trim())
                return "Укажите название и обозначение инструмента";
            if (!(parseAmount(manualValueField.text) > 0))
                return "Укажите стоимость всей позиции в валюте счёта";
            return "";
        }
        if (!selectedInstrument)
            return "Выберите инструмент в результатах поиска";
        if (derivativeSelected)
            return "Контракты добавляются через список позиций";
        return "";
    }

    // A purchase the free money does not cover is funded first, by a transfer from the account the user picks
    function submitBuyWithFunding(when, stamp, note) {
        const problem = buyInputError();
        if (problem.length > 0) {
            localError = problem;
            return;
        }
        const sources = fundingSources();
        const source = fundingBox.currentIndex >= 0 ? sources[fundingBox.currentIndex] : null;
        const shortfall = purchaseShortfallMinor();
        const typed = fundingAmountField.text.trim().length > 0
                    ? Math.round(parseAmount(fundingAmountField.text) * 100) : shortfall;
        if (!source) {
            localError = "Выберите счёт, с которого перевести деньги";
            return;
        }
        if (!(typed >= shortfall)) {
            localError = "Перевод должен покрыть недостающие %1".arg(money(shortfall) + " " + accountCurrency);
            return;
        }
        if (typed > source.balanceMinor) {
            localError = "На счёте «%1» не хватает денег для перевода".arg(source.name);
            return;
        }
        if (!controller.addTransfer(typed, note, source.id, accountId, when)) {
            localError = "Не удалось перевести деньги на брокерский счёт";
            return;
        }
        const bought = submitBuy(stamp, note);
        if (bought.ok)
            close();
        else
            localError = "Перевод выполнен, покупка не прошла: %1. Деньги остались свободными на брокерском счёте."
                .arg(bought.error || "причина не указана");
    }

    function submit() {
        localError = "";
        if (!controller)
            return;
        const when = parseDate(dateField.text);
        if (!when) {
            localError = "Укажите дату и время в формате дд.мм.гггг чч:мм:сс";
            return;
        }
        if (when > new Date()) {
            localError = "Дата операции не может быть в будущем";
            return;
        }
        const stamp = Qt.formatDateTime(when, "dd.MM.yyyy HH:mm:ss");
        const note = descriptionField.text.trim();
        if (mode === "buy" && purchaseShortfallMinor() > 0) {
            submitBuyWithFunding(when, stamp, note);
            return;
        }
        const outcome = mode === "buy" ? submitBuy(stamp, note)
            : mode === "sell" ? submitSell(stamp, note)
            : mode === "charge" ? submitCharge(stamp, note)
            : submitTransfer(when, note);
        if (outcome.ok)
            close();
        else
            localError = outcome.error || "Не удалось записать операцию";
    }

    function submitBuy(stamp, note) {
        const quantity = parseAmount(quantityField.text);
        const cash = parseAmount(cashField.text);
        const fee = commissionMinor(feeField.text, feeUnitBox.currentIndex === 1, Math.round(cash * 100));
        if (!(quantity > 0))
            return fail("Укажите количество больше нуля");
        if (!(cash > 0))
            return fail("Укажите цену покупки или сумму покупки");
        if (isNaN(fee))
            return fail("Комиссия должна быть неотрицательным числом");
        // The price per unit follows from the sum the purchase is booked with
        const price = fixedPrice(priceOfUnit(cash / quantity, selectedFaceRub));
        const spent = (-cash).toFixed(2);
        const commission = (fee / 100).toFixed(2);
        if (manualInstrument) {
            if (!nameField.text.trim() || !symbolField.text.trim())
                return fail("Укажите название и обозначение инструмента");
            const value = parseAmount(manualValueField.text);
            if (!(value > 0))
                return fail("Укажите стоимость всей позиции в валюте счёта");
            return controller.saveInvestmentPosition({accountId: accountId, searchIndex: -2,
                instrumentType: typeBox.currentValue, name: nameField.text.trim(), symbol: symbolField.text.trim(),
                quantity: String(quantity), averagePrice: price, manualValuation: true, manualValue: String(value),
                direction: 1, purchase: true, cashAmount: spent, fee: commission, date: stamp, description: note});
        }
        if (!selectedInstrument)
            return fail("Выберите инструмент в результатах поиска");
        if (derivativeSelected)
            return fail("Контракты добавляются через список позиций");
        const held = heldPositionId(selectedInstrument.id);
        if (held.length > 0)
            return controller.recordInvestmentOperation({positionId: held, kind: "buy", quantity: String(quantity),
                price: price, cashAmount: spent, fee: commission, date: stamp, description: note});
        return controller.saveInvestmentPosition({accountId: accountId, searchIndex: searchResultIndex,
            quantity: String(quantity), averagePrice: price, direction: 1, purchase: true,
            cashAmount: spent, fee: commission, date: stamp, description: note});
    }

    function submitSell(stamp, note) {
        const positions = positionsForSale();
        const position = positionBox.currentIndex >= 0 ? positions[positionBox.currentIndex] : null;
        const quantity = parseAmount(sellQuantityField.text);
        const cash = parseAmount(sellCashField.text);
        const fee = commissionMinor(sellFeeField.text, sellFeeUnitBox.currentIndex === 1, Math.round(cash * 100));
        const tax = optionalAmount(sellTaxField.text);
        if (!position)
            return fail("Выберите позицию, которую продаём");
        if (!(quantity > 0))
            return fail("Укажите количество больше нуля");
        if (quantity > position.held)
            return fail("Нельзя продать больше, чем в наличии: %1".arg(position.heldText));
        if (!(cash > 0))
            return fail("Укажите выручку больше нуля");
        if (isNaN(fee) || tax === "invalid")
            return fail("Комиссия и налог должны быть неотрицательными числами");
        const price = fixedPrice(priceOfUnit(cash / quantity, position.face));
        return controller.recordInvestmentOperation({positionId: position.id, kind: "sell", quantity: String(quantity),
            price: price, cashAmount: cash.toFixed(2), fee: (fee / 100).toFixed(2), tax: tax, date: stamp, description: note});
    }

    function submitTransfer(when, note) {
        const counterpart = counterpartBox.currentIndex >= 0 ? counterparts()[counterpartBox.currentIndex] : null;
        const amount = parseAmount(transferAmountField.text);
        if (!counterpart)
            return fail("Выберите счёт для перевода");
        if (!(amount > 0))
            return fail("Укажите сумму перевода больше нуля");
        const minor = Math.round(amount * 100);
        const outgoing = directionBox.currentIndex === 0;
        if (outgoing && account && account.freeNowMinor < 0)
            return fail("На брокерском счёте минус: переводить с него нельзя, пока задолженность не погашена");
        if (outgoing && account && minor > account.freeNowMinor)
            return fail("Перевести можно только свободные деньги: сейчас %1"
                        .arg(money(account.freeNowMinor) + " " + accountCurrency));
        const moved = controller.addTransfer(minor, note,
                                             outgoing ? accountId : counterpart.id,
                                             outgoing ? counterpart.id : accountId, when);
        return moved ? {ok: true} : fail("Не удалось перевести: проверьте сумму и счета. С фиатного счёта или вклада нельзя перевести больше, чем на нём есть");
    }

    // A commission or a tax taken from the brokerage account itself; the controller checks the free money
    function submitCharge(stamp, note) {
        const amount = parseAmount(chargeAmountField.text);
        if (!(amount > 0))
            return fail("Укажите сумму больше нуля");
        return controller.recordBrokerCharge({accountId: accountId, kind: chargeKindBox.currentValue,
            amount: amount.toFixed(2), date: stamp, description: note});
    }

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

    component ChoiceCard: Rectangle {
        property string heading: ""
        property string hint: ""
        signal picked()
        Layout.fillWidth: true
        implicitHeight: choiceColumn.implicitHeight + 28
        radius: Appearance.desktop ? 0 : 12
        color: dialog.softColor
        border.width: 1
        border.color: dialog.lineColor
        EditorialColumnLayout {
            id: choiceColumn; objectName: "choiceColumn"
            anchors.fill: parent
            anchors.margins: Appearance.desktop ? 16 : 14
            spacing: 4
            EditorialLabel { Layout.fillWidth: true; text: heading; color: dialog.textColor; font.pixelSize: 17; font.weight: Font.DemiBold }
            EditorialLabel { Layout.fillWidth: true; text: hint; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: picked()
        }
    }

    contentItem: EditorialColumnLayout {
        spacing: 12
        EditorialLabel {
            Layout.fillWidth: true; visible: !!dialog.account; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
            text: dialog.account
                ? "%1 · свободно сейчас: %2 · заблокировано: %3 %4"
                    .arg(dialog.account.name)
                    .arg(dialog.money(dialog.account.freeNowMinor))
                    .arg(dialog.money(dialog.account.blockedMarginMinor))
                    .arg(dialog.accountCurrency)
                : ""
        }
        StackLayout {
            id: pages; objectName: "pages"
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: dialog.mode === "buy" ? 1 : dialog.mode === "sell" ? 2 : dialog.mode === "transfer" ? 3 : dialog.mode === "charge" ? 4 : 0

            EditorialColumnLayout {
                spacing: 12
                EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Что делаем с брокерским счётом?"; color: dialog.textColor; font.pixelSize: 17; font.weight: Font.DemiBold }
                ChoiceCard {
                    heading: "Покупка"
                    hint: "Акция, облигация, фонд или другой инструмент. Деньги уйдут с брокерского счёта."
                    onPicked: dialog.chooseMode("buy")
                }
                ChoiceCard {
                    heading: "Продажа"
                    hint: "Продажа инструмента, который уже есть на этом счёте. Выручка останется на счёте."
                    onPicked: dialog.chooseMode("sell")
                }
                ChoiceCard {
                    heading: "Перевод"
                    hint: "Свободные деньги брокера на фиат или вклад и обратно."
                    onPicked: dialog.chooseMode("transfer")
                }
                ChoiceCard {
                    heading: "Комиссия или налог"
                    hint: "Расход брокерского счёта без покупки и продажи: комиссия или налог, который списан с этого счёта."
                    onPicked: dialog.chooseMode("charge")
                }
                Item { Layout.fillHeight: true }
            }

            EditorialScrollView {
                id: buyScroll; objectName: "buyScroll"
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                EditorialColumnLayout {
                    width: buyScroll.availableWidth
                    spacing: 8
                    EditorialLabel { text: "Откуда инструмент"; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                    FormCombo {
                        id: sourceBox; objectName: "sourceBox"; Layout.fillWidth: true
                        model: ["Найти на бирже", "Другой инструмент, вручную"]
                        onActivated: { dialog.localError = ""; dialog.searchResultIndex = -1; }
                    }
                    EditorialRowLayout {
                        Layout.fillWidth: true; visible: !dialog.manualInstrument
                        FormField {
                            id: searchField; objectName: "searchField"; Layout.fillWidth: true
                            placeholderText: "Название, обозначение или ISIN"
                            onAccepted: searchButton.clicked()
                        }
                        FormButton {
                            id: searchButton; objectName: "searchButton"
                            text: dialog.controller && dialog.controller.investmentSearchBusy ? "Ищем…" : "Найти"
                            enabled: !!dialog.controller && !dialog.controller.investmentSearchBusy && searchField.text.trim().length >= 2
                            onClicked: {
                                dialog.searchResultIndex = -1; dialog.localError = "";
                                dialog.controller.searchInvestmentInstruments(searchField.text);
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 150; visible: !dialog.manualInstrument
                        color: dialog.softColor; radius: Appearance.desktop ? 0 : 12; border.width: 1; border.color: dialog.lineColor
                        ListView {
                            anchors.fill: parent; anchors.margins: 8; clip: true; spacing: 4
                            model: dialog.controller ? dialog.controller.investmentSearchResults : []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view.width; height: 56; radius: Appearance.desktop ? 0 : 8
                                color: index === dialog.searchResultIndex ? dialog.hoverColor : "transparent"
                                Column {
                                    anchors.fill: parent; anchors.margins: 8; spacing: Appearance.desktop ? 4 : 3
                                    EditorialLabel {
                                        width: parent.width; text: modelData.symbol + " · " + modelData.name
                                        color: dialog.textColor; font.pixelSize: Appearance.desktop ? 16 : 14; font.weight: Font.DemiBold; elide: Text.ElideRight
                                    }
                                    EditorialLabel {
                                        width: parent.width
                                        text: modelData.typeName + (modelData.hasPrice
                                              ? " · " + modelData.priceText + (modelData.type === 2 ? "%" : " " + modelData.currency) : "")
                                        color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 13; elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    enabled: !!dialog.controller && !dialog.controller.investmentQuoteBusy
                                    onClicked: {
                                        dialog.searchResultIndex = index; dialog.localError = "";
                                        dialog.controller.selectInvestmentSearchResult(index);
                                    }
                                }
                            }
                            EditorialLabel {
                                anchors.centerIn: parent; visible: parent.count === 0; width: parent.width - 24
                                text: "Акции, облигации, фонды, металлы и валюта"
                                color: dialog.mutedColor; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                    FormCombo {
                        id: typeBox; objectName: "typeBox"; Layout.fillWidth: true; visible: dialog.manualInstrument
                        textRole: "name"; valueRole: "value"
                        model: [ {name: "Акция", value: 0}, {name: "Привилегированная акция", value: 5},
                            {name: "Депозитарная расписка", value: 6}, {name: "Биржевой фонд", value: 1},
                            {name: "Пай ПИФ", value: 3}, {name: "Облигация", value: 2},
                            {name: "Драгоценный металл", value: 7}, {name: "Валюта", value: 8},
                            {name: "Другой инструмент", value: 4} ]
                    }
                    FormField { id: nameField; objectName: "nameField"; Layout.fillWidth: true; visible: dialog.manualInstrument; placeholderText: "Название инструмента" }
                    FormField { id: symbolField; objectName: "symbolField"; Layout.fillWidth: true; visible: dialog.manualInstrument; placeholderText: "Обозначение инструмента" }
                    EditorialLabel {
                        Layout.fillWidth: true; visible: dialog.derivativeSelected; wrapMode: Text.WordWrap; color: dialog.errorColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: "Контракты добавляются через список позиций: здесь покупаются акции, облигации, фонды, металлы и валюта."
                    }
                    EditorialLabel {
                        Layout.fillWidth: true
                        visible: !!dialog.selectedInstrument && !dialog.derivativeSelected && !!dialog.selectedInstrument.hasPrice
                        wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: dialog.selectedInstrument
                            ? "Последняя цена: %1".arg(dialog.selectedInstrument.priceText) + (dialog.selectedInstrument.type === 2 ? " %" : " " + dialog.selectedInstrument.currency)
                            : ""
                    }
                    FormField {
                        id: quantityField; objectName: "quantityField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "Количество"
                        onTextEdited: dialog.relinkBuy()
                    }
                    FormField {
                        id: priceField; objectName: "priceField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: dialog.percentPrice
                            ? "Цена покупки, % от номинала"
                            : "Цена покупки за единицу, %1".arg(dialog.selectedInstrument ? dialog.selectedInstrument.currency : dialog.accountCurrency)
                        onTextEdited: { dialog.buyLinkedBy = "price"; dialog.relinkBuy(); }
                    }
                    FormField {
                        id: manualValueField; objectName: "manualValueField"; Layout.fillWidth: true; visible: dialog.manualInstrument; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "Стоимость всей позиции, %1".arg(dialog.accountCurrency)
                    }
                    EditorialLabel {
                        Layout.fillWidth: true; visible: dialog.manualInstrument; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: "Для инструмента с ручной оценкой укажите его текущую стоимость. Разница с суммой покупки станет доходом или убытком."
                    }
                    FormField {
                        id: cashField; objectName: "cashField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "Сумма покупки без комиссии, %1".arg(dialog.accountCurrency)
                        onTextEdited: { dialog.buyLinkedBy = "sum"; dialog.relinkBuy(); }
                    }
                    EditorialColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.desktop ? 8 : 6
                        visible: dialog.purchaseShortfallMinor() > 0
                        EditorialLabel {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: dialog.textColor
                            font.pixelSize: Appearance.desktop ? 16 : 14
                            text: "Свободных денег на счёте не хватает на %1. Откуда перевести?"
                                .arg(dialog.money(dialog.purchaseShortfallMinor()) + " " + dialog.accountCurrency)
                        }
                        FormCombo {
                            id: fundingBox; objectName: "fundingBox"
                            Layout.fillWidth: true
                            model: dialog.fundingSources()
                            textRole: "name"
                            valueRole: "id"
                        }
                        FormField {
                            id: fundingAmountField; objectName: "fundingAmountField"
                            Layout.fillWidth: true
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            placeholderText: "Сумма перевода, %1".arg(dialog.accountCurrency)
                        }
                    }
                    EditorialRowLayout {
                        Layout.fillWidth: true
                        FormField { id: feeField; objectName: "feeField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "Комиссия (необязательно)" }
                        FormCombo { id: feeUnitBox; objectName: "feeUnitBox"; Layout.preferredWidth: 96; model: ["₽", "%"] }
                    }
                    EditorialLabel {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        visible: feeUnitBox.currentIndex === 1 && dialog.commissionMinor(feeField.text, true, Math.round(parseAmount(cashField.text) * 100)) > 0
                        text: "Комиссия составит %1 %2".arg(dialog.money(dialog.commissionMinor(feeField.text, true, Math.round(parseAmount(cashField.text) * 100)))).arg(dialog.accountCurrency)
                    }
                    EditorialLabel {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: "Комиссия спишется со свободных денег брокера отдельной строкой. Если их не хватит, счёт уйдёт в минус, и с него нельзя будет переводить деньги."
                    }
                }
            }

            EditorialScrollView {
                id: sellScroll; objectName: "sellScroll"
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                EditorialColumnLayout {
                    width: sellScroll.availableWidth
                    spacing: 8
                    EditorialLabel { text: "Какую позицию продаём"; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                    FormCombo {
                        id: positionBox; objectName: "positionBox"; Layout.fillWidth: true
                        model: dialog.positionsForSale(); textRole: "name"; valueRole: "id"
                    }
                    EditorialLabel {
                        Layout.fillWidth: true; visible: dialog.selectedSaleHeldText().length > 0
                        wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: "В наличии: %1".arg(dialog.selectedSaleHeldText())
                    }
                    FormField {
                        id: sellQuantityField; objectName: "sellQuantityField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "Количество к продаже"
                        onTextEdited: dialog.relinkSell()
                    }
                    FormField {
                        id: sellPriceField; objectName: "sellPriceField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "Цена продажи за единицу (необязательно)"
                        onTextEdited: { dialog.sellLinkedBy = "price"; dialog.relinkSell(); }
                    }
                    FormField {
                        id: sellCashField; objectName: "sellCashField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "Сумма сделки без комиссии, %1".arg(dialog.accountCurrency)
                        onTextEdited: { dialog.sellLinkedBy = "sum"; dialog.relinkSell(); }
                    }
                    EditorialRowLayout {
                        Layout.fillWidth: true
                        FormField { id: sellFeeField; objectName: "sellFeeField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "Комиссия (необязательно)" }
                        FormCombo { id: sellFeeUnitBox; objectName: "sellFeeUnitBox"; Layout.preferredWidth: 96; model: ["₽", "%"] }
                        FormField { id: sellTaxField; objectName: "sellTaxField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "Налог (необязательно)" }
                    }
                    EditorialLabel {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: "Комиссия и налог запишутся отдельными расходами по этой позиции. Налог вносите фактической суммой, которую удержал брокер."
                    }
                }
            }

            EditorialScrollView {
                id: transferScroll; objectName: "transferScroll"
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                EditorialColumnLayout {
                    width: transferScroll.availableWidth
                    spacing: 8
                    FormCombo {
                        id: directionBox; objectName: "directionBox"; Layout.fillWidth: true
                        model: ["С брокерского счёта: на фиат или вклад", "На брокерский счёт: с фиата или вклада"]
                    }
                    EditorialLabel { text: directionBox.currentIndex === 0 ? "Куда перевести" : "Откуда перевести"; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                    FormCombo {
                        id: counterpartBox; objectName: "counterpartBox"; Layout.fillWidth: true
                        model: dialog.counterparts(); textRole: "name"; valueRole: "id"
                    }
                    EditorialLabel {
                        Layout.fillWidth: true; visible: directionBox.currentIndex === 0 && !!dialog.account
                        wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: dialog.account
                            ? "Можно перевести только свободные деньги: %1. Заблокировано под обеспечение: %2."
                                .arg(dialog.money(dialog.account.freeNowMinor) + " " + dialog.accountCurrency)
                                .arg(dialog.money(dialog.account.blockedMarginMinor) + " " + dialog.accountCurrency)
                            : ""
                    }
                    FormField {
                        id: transferAmountField; objectName: "transferAmountField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: directionBox.currentIndex === 0
                            ? "Сумма, %1 со счёта брокера".arg(dialog.accountCurrency)
                            : "Сумма в валюте счёта-отправителя"
                    }
                    EditorialLabel {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: "Если валюты отличаются, сумма пересчитается по курсу программы."
                    }
                }
            }
            EditorialScrollView {
                id: chargeScroll; objectName: "chargeScroll"
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                EditorialColumnLayout {
                    width: chargeScroll.availableWidth
                    spacing: 8
                    EditorialLabel { text: "Что списано с брокерского счёта"; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                    FormCombo {
                        id: chargeKindBox; objectName: "chargeKindBox"; Layout.fillWidth: true
                        textRole: "name"; valueRole: "value"
                        model: [ {name: "Комиссия брокера", value: "fee"}, {name: "Налог, удержанный брокером", value: "tax"} ]
                    }
                    FormField {
                        id: chargeAmountField; objectName: "chargeAmountField"; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "Сумма, %1 со счёта брокера".arg(dialog.accountCurrency)
                    }
                    EditorialLabel {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14
                        text: "Списывается со свободных денег этого брокерского счёта. Если их не хватит, счёт уйдёт в минус, и с него нельзя будет переводить деньги. Налог вносите фактической суммой, которую удержал брокер."
                    }
                }
            }
        }
        FormField { id: dateField; objectName: "dateField"; Layout.fillWidth: true; visible: dialog.mode !== ""; placeholderText: "Дата и время операции, дд.мм.гггг чч:мм:сс" }
        FormField { id: descriptionField; objectName: "descriptionField"; Layout.fillWidth: true; visible: dialog.mode !== ""; placeholderText: "Описание (необязательно)" }
        EditorialLabel {
            Layout.fillWidth: true; visible: dialog.localError.length > 0; text: dialog.localError
            color: dialog.errorColor; wrapMode: Text.WordWrap; font.pixelSize: Appearance.desktop ? 16 : 14
        }
        EditorialRowLayout {
            Layout.fillWidth: true
            FormButton { text: "Назад"; visible: dialog.mode !== ""; onClicked: { dialog.mode = ""; dialog.localError = ""; } }
            Item { Layout.fillWidth: true }
            FormButton { text: "Отмена"; onClicked: dialog.close() }
            FormButton {
                primary: true; visible: dialog.mode !== ""; text: "Записать"
                enabled: !dialog.busy
                onClicked: dialog.submit()
            }
        }
    }
}
