import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts
import "../computer/common"
import "../computer/dashboard/DashboardData.js" as Data

ApplicationWindow {
    id: root
    width: 390
    height: 844
    minimumWidth: 320
    minimumHeight: 320
    visible: true
    title: "Vexa"
    color: root.canvas
    font.family: MobileTheme.sans
    font.pixelSize: 16

    // Palette values live in MobileTheme so the pages and the shell share one source.
    readonly property color canvas: MobileTheme.canvas
    readonly property color panel: MobileTheme.panel
    readonly property color soft: MobileTheme.soft
    readonly property color line: MobileTheme.line
    readonly property color accent: MobileTheme.accent
    readonly property color muted: MobileTheme.muted
    readonly property color accentSoft: MobileTheme.accentSoft
    readonly property color pale: MobileTheme.pale
    readonly property color paleText: MobileTheme.canvas
    readonly property color red: MobileTheme.red
    readonly property color navSelected: MobileTheme.navSelected
    readonly property color navHovered: "#142B48"

    readonly property color chartAccent1: MobileTheme.chartColors[0]
    readonly property color chartAccent2: MobileTheme.chartColors[1]
    readonly property color chartAccent3: MobileTheme.chartColors[2]
    readonly property color chartAccent4: MobileTheme.chartColors[3]
    readonly property color chartAccent5: MobileTheme.chartColors[4]
    readonly property var chartColors: [chartAccent1, chartAccent2, chartAccent3, chartAccent4, chartAccent5]

    readonly property color tableHeader: MobileTheme.tableHeader
    readonly property color tableRowAlt: MobileTheme.canvas
    readonly property color categoryRow: MobileTheme.canvas
    readonly property color categoryEditRow: MobileTheme.pale
    readonly property color controlHovered: MobileTheme.hover
    readonly property int chartPriceLevels: 7

    readonly property color incomePanel: MobileTheme.incomePanel
    readonly property color expensePanel: MobileTheme.expensePanel
    readonly property color income: MobileTheme.income

    readonly property color white: MobileTheme.accentText
    readonly property color transparentColor: "transparent"

    property string page: "overview"
    onPageChanged: {
        root.clearTransactionSelection();
        browserScroll.stop();
        Qt.inputMethod.hide();
    }
    readonly property var scrollController: browserScroll
    AutoScrollController {
        id: browserScroll
        parent: root.contentItem
    }
    property string searchText: ""
    property bool hideAmounts: false
    onHideAmountsChanged: MobileTheme.hideAmounts = hideAmounts
    readonly property int pageMargin: width < 360 ? 16 : 20
    readonly property int touchHeight: 48
    readonly property var assets: [
        {
            code: "fiat",
            title: qsTr("Фиат"),
            icon: ""
        },
        {
            code: "crypto",
            title: qsTr("Криптовалюта"),
            icon: ""
        },
        {
            code: "investment",
            title: qsTr("Инвестиции"),
            icon: ""
        }
    ]

    function symbol(code) {
        return MobileFormat.symbol(code);
    }
    function uiLocale() {
        return MobileFormat.locale();
    }
    function money(minor, code, sign) {
        return MobileFormat.money(minor, code, sign);
    }

    function assetTitle(code) {
        for (let i = 0; i < assets.length; ++i)
            if (assets[i].code === code)
                return assets[i].title;
        return qsTr("Фиат");
    }

    function assetAmount(code) {
        const rows = financeController.assetSummaries;
        for (let i = 0; i < rows.length; ++i)
            if (rows[i].code === code)
                return rows[i].balanceMinor;
        return 0;
    }

    function accountTypeLabel(type) {
        if (type === "cash")
            return qsTr("Наличные");
        if (type === "debit_card")
            return qsTr("Дебетовая карта");
        if (type === "credit_card")
            return qsTr("Кредитная карта");
        if (type === "crypto_wallet")
            return qsTr("Криптокошелёк");
        if (type === "brokerage")
            return qsTr("Брокер");
        if (type === "deposit")
            return qsTr("Вклад");
        return qsTr("Другой");
    }

    function accountPrimaryAmount(row) {
        if (row && row.isCrypto)
            return row.balanceText + " " + row.symbol;
        if (row && row.isCreditCard)
            return qsTr("Задолженность: %1").arg(root.money(row.debtMinor, row.currency, false)) + (row.countsDebt === false ? qsTr(" · не учитывается") : "");
        return row ? root.money(row.balanceMinor, row.currency, false) : "";
    }

    function accountCompactAmount(row) {
        if (row && row.isCrypto)
            return row.balanceText + " " + row.symbol + " · ≈ " + root.money(row.valueMinor, financeController.appCurrency, false);
        if (row && row.isCreditCard)
            return qsTr("Долг %1 · доступно %2").arg(root.money(row.debtMinor, row.currency, false)).arg(root.money(row.availableCreditMinor, row.currency, false)) + (row.countsDebt === false ? qsTr(" · не учитывается") : "");
        return row ? root.money(row.balanceMinor, row.currency, false) : "";
    }

    function accountAvailableCredit(row) {
        return row && row.isCreditCard ? qsTr("Доступно: %1 из %2").arg(root.money(row.availableCreditMinor, row.currency, false)).arg(root.money(row.creditLimitMinor, row.currency, false)) : "";
    }

    function cryptoWalletStatus(row) {
        if (!row || !row.isCrypto)
            return "";
        if (row.refreshing)
            return qsTr("Обновление баланса…");
        if (row.connectionError)
            return row.connectionError;
        if (!row.hasSnapshot)
            return qsTr("Баланс ещё не обновлён");
        const updated = qsTr("Обновлено: %1").arg(Qt.formatDateTime(row.updatedAt, "dd.MM.yyyy HH:mm"));
        return row.priceHasSnapshot ? updated + " · 1 " + row.symbol + " = " + Number(row.priceUsd).toLocaleString(root.uiLocale(), "f", row.symbol === "USDT" ? 4 : 2) + " $" : updated;
    }

    function accountName(id) {
        const rows = financeController.allAccounts.concat(financeController.cryptoWallets);
        for (let i = 0; i < rows.length; ++i)
            if (rows[i].id === id)
                return rows[i].name;
        return qsTr("Другой счёт");
    }

    function amountForInput(minor) {
        const value = Math.round(Math.abs(Number(minor)));
        const whole = Math.floor(value / 100);
        const cents = value % 100;
        return cents === 0 ? String(whole) : String(whole) + "." + (cents < 10 ? "0" : "") + String(cents);
    }

    function signedAmountForInput(minor) {
        return Number(minor) < 0 ? "-" + amountForInput(minor) : amountForInput(minor);
    }

    function transactionSignedAmount(row) {
        if (row.type === "investment_cash" || row.type === "investment_position")
            return row.amount;
        return row.type === "income" || (row.type === "transfer" && row.direction === "in") ? row.amount : -row.amount;
    }

    function transactionTypeLabel(row) {
        if (row.type === "investment_cash" || row.type === "investment_position")
            return qsTr("Инвестиция");
        if (row.type === "transfer")
            return qsTr("Перевод");
        return row.type === "income" ? qsTr("Доход") : qsTr("Расход");
    }

    function indexByRole(model, role, value) {
        for (let i = 0; i < model.length; ++i)
            if (model[i][role] === value)
                return i;
        return model.length > 0 ? 0 : -1;
    }

    function openTransactionContextMenu(row, sourceItem, localX, localY) {
        const point = sourceItem.mapToItem(root.contentItem, localX, localY);
        transactionContextMenu.transactionData = row;
        transactionContextMenu.x = Math.max(8, Math.min(point.x, root.contentItem.width - transactionContextMenu.width - 8));
        transactionContextMenu.y = Math.max(8, Math.min(point.y, root.contentItem.height - transactionContextMenu.implicitHeight - 8));
        transactionContextMenu.open();
    }

    function openAccountContextMenu(row, sourceItem, localX, localY) {
        if (!row || !row.id)
            return;
        const point = sourceItem.mapToItem(root.contentItem, localX, localY);
        accountContextMenu.accountData = row;
        accountContextMenu.x = Math.max(8, Math.min(point.x, root.contentItem.width - accountContextMenu.width - 8));
        accountContextMenu.y = Math.max(8, Math.min(point.y, root.contentItem.height - accountContextMenu.implicitHeight - 8));
        accountContextMenu.open();
    }

    function calendarLabel(year, month) {
        const label = root.uiLocale().standaloneMonthName(month);
        return label.charAt(0).toUpperCase() + label.slice(1) + " " + year;
    }
    function dateFromIso(value) {
        if (!value)
            return null;
        const parts = value.split("-");
        if (parts.length !== 3)
            return null;
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 12, 0, 0, 0);
    }

    function dateFilterLabel() {
        if (!financeController.dateFilterActive)
            return qsTr("Все время");
        const from = dateFromIso(financeController.dateFilterFrom);
        const to = dateFromIso(financeController.dateFilterTo);
        if (!from || !to)
            return qsTr("Все время");
        if (from.getTime() === to.getTime())
            return Qt.formatDate(from, "dd.MM.yyyy");
        return Qt.formatDate(from, "dd.MM.yyyy") + " — " + Qt.formatDate(to, "dd.MM.yyyy");
    }

    function transactionSummary(row) {
        // A transfer names its side: "Перевод НА …" on the outgoing row, "Перевод С …" on the incoming one
        if (row.type === "transfer" && row.transferLabel) {
            if (row.investmentTransfer || !row.rawDescription)
                return row.transferLabel;
            return row.transferLabel + " · " + row.rawDescription;
        }
        if (row.recipientSource)
            return row.recipientName || qsTr("Получатель не определён");
        return row.rawDescription || row.description || "—";
    }

    function visibleTransactions() {
        const result = [], ids = {}, accounts = financeController.accounts;
        for (let i = 0; i < accounts.length; ++i)
            ids[accounts[i].id] = true;
        const rows = financeController.transactions.concat(financeController.selectedAsset === "investment" ? financeController.investmentOperations : []), query = searchText.trim().toLowerCase();
        for (let j = 0; j < rows.length; ++j) {
            const row = rows[j];
            if (!ids[row.accountId])
                continue;
            if (financeController.selectedAccountId && row.accountId !== financeController.selectedAccountId)
                continue;
            const text = ((row.description || row.rawDescription || "") + " " + (row.recipientName || "") + " " + row.categoryName + " " + accountName(row.accountId)).toLowerCase();
            if (!query || text.indexOf(query) >= 0)
                result.push(row);
        }
        result.sort(function (a, b) {
            return new Date(b.date).getTime() - new Date(a.date).getTime();
        });
        return result;
    }

    function categoryTotals() {
        const values = {}, names = {}, rows = visibleTransactions();
        for (let i = 0; i < rows.length; ++i) {
            if (rows[i].type !== "expense")
                continue;
            const id = rows[i].categoryId || "none";
            values[id] = (values[id] || 0) + Number(rows[i].displayAmount);
            names[id] = rows[i].categoryName || qsTr("Без категории");
        }
        const result = [];
        for (const id in values)
            result.push({
                label: names[id],
                amount: values[id]
            });
        result.sort(function (a, b) {
            return b.amount - a.amount;
        });
        return result.slice(0, 5);
    }

    // Neobrutalism shadow: a solid accent copy of the shape 4 px below, without blur (as in the Figma design)
    component HardShadow: Rectangle {
        visible: false
        x: 0
        y: 4
        z: -1
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        radius: parent ? parent.radius : 0
        color: root.accent
    }

    component Panel: Rectangle {
        HardShadow {}

        color: root.panel
        radius: 0
        border.width: 1
        border.color: root.accent
    }

    // Item.clip and ListView.clip are rectangular. These masks cover content
    // that would otherwise remain visible outside the rounded bottom corners.
    component BottomCornerMask: Canvas {
        id: cornerMask
        property bool mirrored: false

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onMirroredChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const radius = Math.min(width, height);
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = root.canvas;
            ctx.beginPath();

            if (mirrored) {
                ctx.moveTo(width, 0);
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                ctx.arc(0, 0, radius, Math.PI / 2, 0, true);
            } else {
                ctx.moveTo(0, 0);
                ctx.lineTo(0, height);
                ctx.lineTo(width, height);
                ctx.arc(width, 0, radius, Math.PI / 2, Math.PI, false);
            }

            ctx.closePath();
            ctx.fill();
        }
    }
    component SoftButton: StyledButton {
        primary: highlighted
        controlHeight: root.touchHeight
        appTextColor: root.accent
        appMutedColor: root.muted
        appPanelColor: root.panel
        appSoftColor: root.soft
        appLineColor: root.line
        appAccentColor: root.accent
        appHoverColor: root.controlHovered
        appOnAccentColor: root.white
        appErrorColor: root.red
    }

    component AppMenuItem: MenuItem {
        id: menuItem
        property bool destructive: false
        hoverEnabled: true
        implicitHeight: root.touchHeight
        leftPadding: 12
        rightPadding: 12

        contentItem: MobileText {
            font.family: MobileTheme.sans
            text: menuItem.text
            color: menuItem.destructive ? root.red : root.accent
            font.pixelSize: 16
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 0
            color: menuItem.highlighted || menuItem.hovered ? (menuItem.destructive ? root.expensePanel : root.controlHovered) : root.transparentColor
        }
    }
    component AppTextField: StyledTextField {
        controlHeight: root.touchHeight
        appTextColor: root.accent
        appMutedColor: root.muted
        appPanelColor: root.panel
        appSoftColor: root.soft
        appLineColor: root.line
        appAccentColor: root.navSelected
        appOnAccentColor: root.white
    }
    component AppCheckBox: StyledCheckBox {
        appTextColor: root.accent
        appMutedColor: root.muted
        appSoftColor: root.soft
        appLineColor: root.line
        appAccentColor: root.accent
        appHoverColor: root.controlHovered
        appOnAccentColor: root.white
    }
    component AppComboBox: StyledComboBox {
        controlHeight: root.touchHeight
        appTextColor: root.accent
        appMutedColor: root.muted
        appPanelColor: root.panel
        appSoftColor: root.soft
        appLineColor: root.line
        appAccentColor: root.navSelected
        appHoverColor: root.controlHovered
    }
    readonly property var createPages: ["overview", "categories", "scheduled", "budgets", "goals", "projects", "project"]
    signal createRequested(string key)
    readonly property var tabItems: [
        {
            key: "overview",
            title: qsTr("Обзор"),
            icon: "home"
        },
        {
            key: "categories",
            title: qsTr("Категории"),
            icon: "tag"
        },
        {
            key: "add",
            title: qsTr("Добавить"),
            icon: "plus",
            disabled: createPages.indexOf(page) < 0 || (page === "overview" && (financeController.selectedAsset === "crypto" || (financeController.selectedAsset === "investment" && financeController.accounts.length === 0)))
        },
        {
            key: "scheduled",
            title: qsTr("Плановые"),
            icon: "calendar"
        },
        {
            key: "more",
            title: qsTr("Ещё"),
            icon: "more"
        }
    ]
    readonly property var pageTitles: ({
            overview: qsTr("Мои финансы"),
            analytics: qsTr("Аналитика"),
            more: qsTr("Ещё"),
            categories: qsTr("Категории"),
            budgets: qsTr("Бюджеты"),
            goals: qsTr("Цели"),
            trajectory: qsTr("Траектория"),
            scheduled: qsTr("Плановые операции"),
            projects: qsTr("Проекты"),
            notes: qsTr("Заметки"),
            settings: qsTr("Настройки"),
            data: qsTr("Импорт и экспорт")
        })
    readonly property bool periodControls: page === "overview" || page === "analytics"
    readonly property bool moneyControls: ["overview", "analytics", "scheduled", "budgets", "goals", "trajectory", "projects", "project"].indexOf(page) >= 0
    readonly property bool globalFilters: periodControls
    readonly property string tabKey: ["overview", "categories", "scheduled"].indexOf(page) >= 0 ? page : "more"
    readonly property string historyAccountId: financeController.selectedAsset === "crypto" ? financeController.selectedCryptoWalletId : financeController.selectedAccountId
    property string historyCategory: ""
    property string historySort: "date"
    property int historyDirection: -1
    function openCurrency() {
        clearTransactionSelection();
        currencySheet.open();
    }
    function openPeriod() {
        clearTransactionSelection();
        dateFilterDialog.openForCurrent();
    }
    function addPosition() {
        investmentPositionDialog.openForNewPosition();
    }
    function editPosition(row) {
        investmentPositionDialog.openForEdit(row);
    }
    function positionOperation(row) {
        investmentOperationDialog.openFor(row);
    }
    function addAccount() {
        clearTransactionSelection();
        if (financeController.selectedAsset === "crypto")
            cryptoWalletDialog.openForNewWallet();
        else
            accountDialog.openForSelectedAsset();
    }
    function createCategory(type) {
        categoryDialog.openForManagement();
        categoryType.currentIndex = type === "expense" ? 1 : 0;
    }
    function editCategory(row) {
        categoryDialog.openForEdit(row);
    }
    function createCurrent() {
        clearTransactionSelection();
        if (page === "overview")
            openNewOperation();
        else
            createRequested(page);
    }
    function investmentOperationRow(position) {
        return Object.assign({}, position, {
            instrumentType: position.type,
            type: "investment_position",
            amount: position.marketValueMinor,
            rawDescription: position.symbol + " · " + position.name + " · " + position.quantityText,
            categoryName: position.typeName,
            date: new Date(position.createdAt)
        });
    }
    function historyRows() {
        return Data.filterRows(Data.history(financeController, root, financeController.selectedAsset, historyAccountId), searchText, historyCategory, historySort, historyDirection);
    }
    function selectHistoryAccount(row) {
        clearTransactionSelection();
        const value = historyAccountId === row.id ? "" : row.id;
        if (financeController.selectedAsset === "crypto")
            financeController.selectedCryptoWalletId = value;
        else
            financeController.selectedAccountId = value;
    }
    function clearHistoryAccount() {
        financeController.selectedAccountId = "";
        financeController.selectedCryptoWalletId = "";
    }
    function openSelectionMenu(source, x, y) {
        selectionMenu.popup(source, x, y);
    }
    property var pageHistory: []

    function pageTitle() {
        if (page === "project") {
            const rows = financeController.projects;
            for (let i = 0; i < rows.length; ++i)
                if (rows[i].id === financeController.selectedProjectId)
                    return rows[i].name;
            return qsTr("Проект");
        }
        return pageTitles[page] || "";
    }

    function openTab(key) {
        pageHistory = [];
        clearTransactionSelection();
        page = key;
    }

    // Several operations at once, keyed as on the computer (HistorySelection.key)
    property var transactionSelection: ({})
    readonly property int transactionSelectionCount: Object.keys(transactionSelection).length

    function transactionKey(row) {
        return row.transactionId ? "crypto:" + row.walletId + ":" + row.transactionId : (row.type || "operation") + ":" + row.id;
    }
    function isTransactionSelected(row) {
        return !!row && transactionSelection[transactionKey(row)] !== undefined;
    }
    function toggleTransactionSelection(row) {
        if (!row)
            return;
        const next = Object.assign({}, transactionSelection);
        const key = transactionKey(row);
        if (next[key] !== undefined)
            delete next[key];
        else
            next[key] = row;
        transactionSelection = next;
    }
    function clearTransactionSelection() {
        if (transactionSelectionCount > 0)
            transactionSelection = ({});
    }
    // Every operation shown in the history on the overview (the current search and asset included)
    function selectAllVisibleTransactions() {
        const next = {};
        root.historyRows().forEach(function (item) {
            next[transactionKey(item.source)] = item.source;
        });
        transactionSelection = next;
    }
    function selectedTransactionRows() {
        return Object.keys(transactionSelection).map(function (key) {
            return transactionSelection[key];
        });
    }

    function selectedInvestmentAccount() {
        const accounts = financeController.accounts;
        for (let i = 0; i < accounts.length; ++i)
            if (accounts[i].id === financeController.selectedAccountId)
                return accounts[i];
        return null;
    }

    // The same routing as on the computer: a brokerage account takes purchases, sales, transfers and charges
    function openNewOperation() {
        if (financeController.selectedAsset === "crypto")
            return;
        if (financeController.selectedAsset !== "investment") {
            operationDialog.openForNew();
            return;
        }
        let account = selectedInvestmentAccount();
        if (!account && financeController.accounts.length > 0) {
            account = financeController.accounts[0];
            financeController.selectedAccountId = account.id;
        }
        if (!account)
            return;
        if (account.type === "brokerage")
            brokerOperationDialog.openFor(account.id);
        else
            operationDialog.openForNew();
    }

    function exchangeSection(section) {
        const names = {
            FundingAccount: qsTr("Финансирование"),
            UnifiedTradingAccount: qsTr("Торговый счёт"),
            Earn: qsTr("Накопления"),
            TradingBot: qsTr("Торговые боты"),
            CopyTrading: qsTr("Копирование сделок"),
            CryptoLoans: qsTr("Криптозаймы"),
            CryptoLoans_legacy: qsTr("Криптозаймы"),
            Launchpool: qsTr("Пул вознаграждений")
        };
        return names[section] || section;
    }

    function openPage(key) {
        clearTransactionSelection();
        if (key === page)
            return;
        pageHistory = pageHistory.concat([page]);
        page = key;
    }

    function goBack() {
        if (pageHistory.length > 0) {
            const previous = pageHistory.slice();
            page = previous.pop();
            pageHistory = previous;
            return true;
        }
        if (page !== "overview") {
            page = "overview";
            return true;
        }
        return false;
    }

    Item {
        id: shell
        anchors.fill: parent
        readonly property real safeTop: SafeArea.margins.top
        focus: true
        Keys.onBackPressed: function (event) {
            if (root.transactionSelectionCount) {
                root.clearTransactionSelection();
                event.accepted = true;
            } else
                event.accepted = root.goBack();
        }
        Keys.onEscapePressed: root.clearTransactionSelection()
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: tabBar.top
            anchors.leftMargin: root.pageMargin
            anchors.rightMargin: root.pageMargin
            anchors.topMargin: shell.safeTop + 16
            anchors.bottomMargin: root.transactionSelectionCount ? 60 : 0
            spacing: 24
            MobilePageHeader {
                Layout.fillWidth: true
                visible: root.page !== "overview"
                host: root
            }
            CachedPages {
                objectName: "mobilePages"
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentKey: root.page
                pages: [
                    {
                        key: "overview",
                        component: overviewPage
                    },
                    {
                        key: "categories",
                        component: categoriesPage
                    },
                    {
                        key: "analytics",
                        component: analyticsPage
                    },
                    {
                        key: "scheduled",
                        component: scheduledPage
                    },
                    {
                        key: "more",
                        component: morePage
                    },
                    {
                        key: "settings",
                        component: settingsPage
                    },
                    {
                        key: "data",
                        component: dataPage
                    },
                    {
                        key: "budgets",
                        component: budgetsPage
                    },
                    {
                        key: "goals",
                        component: goalsPage
                    },
                    {
                        key: "trajectory",
                        component: trajectoryPage
                    },
                    {
                        key: "projects",
                        component: projectsPage
                    },
                    {
                        key: "project",
                        component: projectPage
                    },
                    {
                        key: "notes",
                        component: notesPage
                    }
                ]
            }
        }
        Rectangle {
            visible: root.transactionSelectionCount > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: tabBar.top
            height: 60
            color: root.panel
            Rectangle {
                width: parent.width
                height: 1
                color: root.accent
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.pageMargin
                anchors.rightMargin: root.pageMargin
                spacing: 8
                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: qsTr("Выбрано: %1").arg(root.transactionSelectionCount)
                    font.pixelSize: 12
                }
                MobileIconButton {
                    icon: "check"
                    Accessible.name: qsTr("Выделить все")
                    onClicked: root.selectAllVisibleTransactions()
                }
                MobileIconButton {
                    icon: "close"
                    Accessible.name: qsTr("Снять выделение")
                    onClicked: root.clearTransactionSelection()
                }
                MobileIconButton {
                    icon: "trash"
                    Accessible.name: qsTr("Удалить выделенные")
                    onClicked: transactionDeleteSheet.openFor()
                }
            }
        }
        MobileTabBar {
            id: tabBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: implicitHeight
            items: root.tabItems
            activeKey: root.tabKey
            onSelected: function (key) {
                if (key === "add")
                    root.createCurrent();
                else
                    root.openTab(key);
            }
        }
    }
    Menu {
        id: selectionMenu
        width: Math.min(280, root.width - 32)
        AppMenuItem {
            text: qsTr("Выделить все")
            onTriggered: root.selectAllVisibleTransactions()
        }
        AppMenuItem {
            text: qsTr("Удалить выделенные")
            destructive: true
            onTriggered: transactionDeleteSheet.openFor()
        }
        AppMenuItem {
            text: qsTr("Редактировать")
            visible: root.transactionSelectionCount === 1
            height: visible ? implicitHeight : 0
            enabled: {
                const row = root.selectedTransactionRows()[0];
                return !!row && !row.cryptoRow && row.type !== "investment_cash" && row.type !== "investment_position" && !row.investmentTransfer;
            }
            onTriggered: {
                const row = root.selectedTransactionRows()[0];
                root.clearTransactionSelection();
                operationDialog.openForEdit(row);
            }
        }
        background: Rectangle {
            color: root.panel
            border.width: 1
            border.color: root.line
        }
    }

    MobileSheet {
        id: currencySheet

        title: qsTr("Валюта")

        MobileCard {
            Layout.fillWidth: true
            cardPadding: 0
            gap: 0

            Repeater {
                model: ["RUB", "USD", "EUR", "CNY"]

                delegate: MobileListRow {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    first: index === 0
                    title: modelData
                    marked: financeController.appCurrency === modelData
                    onClicked: {
                        financeController.appCurrency = modelData;
                        currencySheet.close();
                    }
                }
            }
        }
    }

    Component {
        id: morePage

        MobileMorePage {
            onNavigate: function (key) {
                root.openPage(key);
            }
        }
    }

    Component {
        id: budgetsPage

        MobileBudgetsPage {
            id: budgetsInstance
            Connections {
                target: root
                function onCreateRequested(key) {
                    if (key === "budgets")
                        budgetsInstance.create();
                }
            }
        }
    }

    Component {
        id: goalsPage

        MobileGoalsPage {
            id: goalsInstance
            Connections {
                target: root
                function onCreateRequested(key) {
                    if (key === "goals")
                        goalsInstance.create();
                }
            }
        }
    }

    Component {
        id: trajectoryPage

        MobileTrajectoryPage {}
    }

    Component {
        id: scheduledPage

        MobileScheduledPage {
            id: scheduledInstance
            Connections {
                target: root
                function onCreateRequested(key) {
                    if (key === "scheduled")
                        scheduledInstance.create();
                }
            }
        }
    }

    Component {
        id: dataPage

        MobileDataPage {
            onBankStatementChosen: function (file) {
                bankCsvImportDialog.openForFile(file);
            }
        }
    }

    Component {
        id: projectsPage

        MobileProjectsPage {
            id: projectsInstance
            Connections {
                target: root
                function onCreateRequested(key) {
                    if (key === "projects")
                        projectsInstance.create();
                }
            }
            onNavigate: function (key) {
                root.openPage(key);
            }
        }
    }

    Component {
        id: projectPage

        MobileProjectPage {
            id: projectInstance
            Connections {
                target: root
                function onCreateRequested(key) {
                    if (key === "project")
                        projectInstance.create();
                }
            }
            onDone: root.goBack()
        }
    }

    Component {
        id: notesPage

        MobileNotesPage {}
    }

    // ---- Overview (design): balance card, asset strip, accounts of the asset, history ----
    readonly property color designIncome: "#2E8963"
    readonly property color designExpense: "#2D0300"
    property bool overviewSearchOpen: false

    function shownAmount(text) {
        return root.hideAmounts ? "******" : text;
    }

    function assetRows() {
        return financeController.selectedAsset === "crypto" ? financeController.cryptoWallets : financeController.accounts;
    }

    function rowPrimaryAmount(row) {
        if (row.isExchange)
            return row.hasSnapshot ? root.money(row.valueMinor, financeController.appCurrency, false) : qsTr("Нет данных");
        if (row.isCrypto)
            return row.balanceText + " " + row.symbol;
        if (row.isCreditCard)
            return root.money(row.debtMinor, row.currency, false);
        return root.money(row.balanceMinor, row.currency, false);
    }

    function dayKey(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    // Operations grouped by day: header items ("Сегодня", "Вчера", dd.MM.yyyy) and row items
    function overviewHistoryItems() {
        const rows = visibleTransactions();
        const today = new Date();
        const yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
        const todayKey = dayKey(today);
        const yesterdayKey = dayKey(yesterday);
        const items = [];
        let lastKey = "";
        for (let i = 0; i < rows.length; ++i) {
            const date = new Date(rows[i].date);
            const key = dayKey(date);
            if (key !== lastKey) {
                items.push({
                    header: true,
                    label: key === todayKey ? qsTr("Сегодня") : key === yesterdayKey ? qsTr("Вчера") : Qt.formatDate(date, "dd.MM.yyyy")
                });
                lastKey = key;
            }
            items.push({
                header: false,
                row: rows[i]
            });
        }
        return items;
    }

    // Horizontal swipe on the dashboard switches the asset: left = next, right = previous.
    // Vertical or short moves do nothing, so scrolling and taps keep working.
    function overviewSwipe(dx, dy) {
        if (Math.abs(dx) < 60 || Math.abs(dx) < 1.5 * Math.abs(dy))
            return false;
        const order = ["fiat", "crypto", "investment"];
        const next = order.indexOf(financeController.selectedAsset) + (dx < 0 ? 1 : -1);
        if (next >= 0 && next < order.length)
            financeController.selectedAsset = order[next];
        return true;
    }

    // Round tool button of the balance card. selected = pressed look (e.g. an active date filter)
    // Round 32 px button of the overview header: a flat circle with an icon or a glyph (no outline, no shadow)
    component RoundTool: Item {
        id: tool

        property string icon: ""
        property string glyph: ""
        property bool selected: false
        signal clicked

        width: 32
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: tool.selected ? MobileTheme.accent : tap.pressed ? MobileTheme.hover : MobileTheme.designCard
        }

        MobileIcon {
            anchors.centerIn: parent
            visible: tool.icon.length > 0
            name: tool.icon
            width: 24
            height: 24
            color: tool.selected ? MobileTheme.designCream : MobileTheme.designInk
        }

        MobileText {
            font.family: MobileTheme.sans
            anchors.centerIn: parent
            visible: tool.glyph.length > 0
            text: tool.glyph
            color: tool.selected ? MobileTheme.designCream : MobileTheme.designInk
            font.pixelSize: 23
            font.weight: Font.Bold
        }

        MouseArea {
            id: tap

            property real pressX: 0
            property real pressY: 0

            anchors.fill: parent
            onPressed: function (mouse) {
                pressX = mouse.x;
                pressY = mouse.y;
            }
            onReleased: function (mouse) {
                root.overviewSwipe(mouse.x - pressX, mouse.y - pressY);
            }
            onClicked: function (mouse) {
                if (Math.abs(mouse.x - pressX) <= 40)
                    tool.clicked();
            }
        }
    }

    // Card of the overview: 1 px outline and a soft shadow (dy 2, blur 2.3, accent at 44 %) as in the frame
    component SoftCard: Rectangle {
        radius: 0
        color: MobileTheme.designCard

        RectangularShadow {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            blur: 2.3
            spread: 0
            offset: Qt.vector2d(0, 2)
            color: MobileTheme.designShadow
            cached: false
        }
    }

    // Text placed by frame coordinates: baseY is the baseline; anchorX is the left origin (mode 0), the right edge
    // of the advance box (mode 1) or its centre (mode 2). The top of the line follows from the font ascent.
    component DText: MobileText {
        id: dt

        property real baseY: 0
        property real anchorX: 0
        property int anchorMode: 0

        x: anchorMode === 0 ? anchorX : (anchorMode === 1 ? anchorX - implicitWidth : anchorX - implicitWidth / 2)
        y: baseY - metrics.ascent

        FontMetrics {
            id: metrics
            font: dt.font
        }
    }

    // Overview as in the frame "finance_ui_neobrutal_calm". Frame y is measured from the top of the status band
    // (frame y 44); the page starts at the device's top inset, so the band follows the camera cutout. The band with
    // the title and the round tools stays on top; the rest scrolls under it. Right-side items anchor to the right edge.
    Component {
        id: overviewPage
        MobileEditorialOverview {
            host: root
        }
    }

    // One shared transaction container for both Overview and Operations.
    // The Panel owns the ONLY outer outline; its contents stay 1 px inside it
    // so opaque table rows never paint over the border.
    // Shared transaction container for Overview and Operations.
    // On Overview expandToContent=true: the transaction history grows with its rows,
    // so the OUTER overview ScrollView owns vertical scrolling.
    // On Operations expandToContent=false: the block fills the page and keeps its own ListView.
    component TransactionBlock: Panel {
        id: transactionBlock

        property string title: qsTr("История операций")
        property var rows: []
        property bool expandToContent: false

        // 68 px block header + 34 px table header + 38 px per transaction + 2 px frame inset.
        // Keep these values in sync with TransactionTable row/header heights below.
        implicitHeight: expandToContent ? 104 + rows.length * 38 : 245

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 13
                Layout.rightMargin: 13
                Layout.topMargin: 13
                Layout.bottomMargin: 13

                MobileText {
                    font.family: MobileTheme.sans
                    text: transactionBlock.title
                    color: root.accent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Item {
                    Layout.fillWidth: true
                }

                SoftButton {
                    text: qsTr("+  Операция")
                    highlighted: true
                    implicitWidth: 132
                    onClicked: root.openNewOperation()
                }
            }

            TransactionTable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                rows: transactionBlock.rows
                expandToContent: transactionBlock.expandToContent
                bottomCornerRadius: transactionBlock.radius - 1
            }
        }

        BottomCornerMask {
            width: transactionBlock.radius
            height: transactionBlock.radius
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            z: 999
        }

        BottomCornerMask {
            width: transactionBlock.radius
            height: transactionBlock.radius
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            mirrored: true
            z: 999
        }

        // IMPORTANT: frame is deliberately rendered ABOVE all table content.
        Rectangle {
            anchors.fill: parent
            color: root.transparentColor
            radius: transactionBlock.radius
            border.width: 1
            border.color: root.line
            z: 1000
        }
    }

    component TransactionTable: Item {
        id: transactionTable

        property var rows: []
        property real bottomCornerRadius: 0
        property bool expandToContent: false

        readonly property int tableHeaderHeight: 34
        readonly property int rowHeight: 38
        readonly property int operationColumnWidth: 100
        readonly property int accountColumnWidth: 150
        readonly property int categoryColumnWidth: 160
        readonly property int dateColumnWidth: 110
        readonly property int amountColumnWidth: 130

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                height: transactionTable.tableHeaderHeight
                color: root.tableHeader

                // Only the header/content divider is drawn here.
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: root.line
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22

                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Операция")
                        color: root.muted
                        font.pixelSize: 16
                        Layout.preferredWidth: transactionTable.operationColumnWidth
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Счёт")
                        color: root.muted
                        font.pixelSize: 16
                        Layout.preferredWidth: transactionTable.accountColumnWidth
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Категория")
                        color: root.muted
                        font.pixelSize: 16
                        Layout.preferredWidth: transactionTable.categoryColumnWidth
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Описание")
                        color: root.muted
                        font.pixelSize: 16
                        Layout.fillWidth: true
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Дата")
                        color: root.muted
                        font.pixelSize: 16
                        Layout.preferredWidth: transactionTable.dateColumnWidth
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Сумма")
                        color: root.muted
                        font.pixelSize: 16
                        Layout.preferredWidth: transactionTable.amountColumnWidth
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.fill: parent
                    color: root.white
                    radius: transactionTable.bottomCornerRadius

                    // Rectangle.radius rounds all four corners; cover upper pair so the
                    // body remains square where it touches the table header.
                    Rectangle {
                        visible: parent.radius > 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: Math.min(parent.radius, parent.height)
                        color: root.white
                    }
                }

                // OVERVIEW MODE: ordinary non-flickable content.
                // The whole overview page scrolls as one document.
                Column {
                    anchors.fill: parent
                    visible: transactionTable.expandToContent

                    Repeater {
                        model: transactionTable.rows

                        delegate: Item {
                            required property int index
                            required property var modelData
                            width: parent.width
                            height: transactionTable.rowHeight

                            Rectangle {
                                anchors.fill: parent
                                color: index % 2 ? root.tableRowAlt : root.panel
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 22
                                anchors.rightMargin: 22

                                MobileText {
                                    font.family: MobileTheme.sans
                                    text: root.transactionTypeLabel(modelData)
                                    color: root.accent
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    Layout.preferredWidth: transactionTable.operationColumnWidth
                                    elide: Text.ElideRight
                                }
                                MobileText {
                                    font.family: MobileTheme.sans
                                    text: root.accountName(modelData.accountId)
                                    color: root.muted
                                    font.pixelSize: 16
                                    Layout.preferredWidth: transactionTable.accountColumnWidth
                                    elide: Text.ElideRight
                                }
                                MobileText {
                                    font.family: MobileTheme.sans
                                    text: modelData.categoryName
                                    color: root.accent
                                    font.pixelSize: 16
                                    Layout.preferredWidth: transactionTable.categoryColumnWidth
                                    elide: Text.ElideRight
                                }
                                MobileText {
                                    font.family: MobileTheme.sans
                                    text: root.transactionSummary(modelData)
                                    color: root.muted
                                    font.pixelSize: 16
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                MobileText {
                                    font.family: MobileTheme.sans
                                    text: Qt.formatDateTime(new Date(modelData.date), "dd.MM.yyyy")
                                    color: root.muted
                                    font.pixelSize: 16
                                    Layout.preferredWidth: transactionTable.dateColumnWidth
                                }
                                MobileText {
                                    font.family: MobileTheme.sans
                                    text: root.money(root.transactionSignedAmount(modelData), modelData.currency, true)
                                    color: modelData.type === "transfer" ? root.navSelected : (modelData.type === "income" || (modelData.type === "investment_cash" && modelData.amount >= 0)) ? root.income : root.red
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: transactionTable.amountColumnWidth
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            MouseArea {
                                id: overviewRowMenuArea
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onPressed: function (mouse) {
                                    if (mouse.button === Qt.RightButton)
                                        root.openTransactionContextMenu(modelData, overviewRowMenuArea, mouse.x, mouse.y);
                                }
                            }
                        }
                    }
                }

                // OPERATIONS PAGE MODE: virtualized scrollable list remains useful for
                // potentially large transaction histories. Scrollbar itself stays hidden.
                ListView {
                    id: transactionList
                    anchors.fill: parent
                    visible: !transactionTable.expandToContent
                    clip: true
                    ScrollBar.horizontal: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                    }
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                    }
                    model: transactionTable.rows

                    delegate: Item {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: transactionTable.rowHeight

                        Rectangle {
                            anchors.fill: parent
                            color: index % 2 ? root.tableRowAlt : root.panel
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 22
                            anchors.rightMargin: 22

                            MobileText {
                                font.family: MobileTheme.sans
                                text: root.transactionTypeLabel(modelData)
                                color: root.accent
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                Layout.preferredWidth: transactionTable.operationColumnWidth
                                elide: Text.ElideRight
                            }
                            MobileText {
                                font.family: MobileTheme.sans
                                text: root.accountName(modelData.accountId)
                                color: root.muted
                                font.pixelSize: 16
                                Layout.preferredWidth: transactionTable.accountColumnWidth
                                elide: Text.ElideRight
                            }
                            MobileText {
                                font.family: MobileTheme.sans
                                text: modelData.categoryName
                                color: root.accent
                                font.pixelSize: 16
                                Layout.preferredWidth: transactionTable.categoryColumnWidth
                                elide: Text.ElideRight
                            }
                            MobileText {
                                font.family: MobileTheme.sans
                                text: root.transactionSummary(modelData)
                                color: root.muted
                                font.pixelSize: 16
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            MobileText {
                                font.family: MobileTheme.sans
                                text: Qt.formatDateTime(new Date(modelData.date), "dd.MM.yyyy")
                                color: root.muted
                                font.pixelSize: 16
                                Layout.preferredWidth: transactionTable.dateColumnWidth
                            }
                            MobileText {
                                font.family: MobileTheme.sans
                                text: root.money(root.transactionSignedAmount(modelData), modelData.currency, true)
                                color: modelData.type === "transfer" ? root.navSelected : (modelData.type === "income" || (modelData.type === "investment_cash" && modelData.amount >= 0)) ? root.income : root.red
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: transactionTable.amountColumnWidth
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        MouseArea {
                            id: operationsRowMenuArea
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onPressed: function (mouse) {
                                if (mouse.button === Qt.RightButton)
                                    root.openTransactionContextMenu(modelData, operationsRowMenuArea, mouse.x, mouse.y);
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: transactionTable.rows.length === 0
                    text: qsTr("Операций пока нет")
                    color: root.muted
                }
            }
        }
    }

    component MobileTransactionCard: Rectangle {
        id: mobileTransactionCard
        HardShadow {}
        property var rowData: null
        property int rowIndex: 0

        width: parent ? parent.width : 0
        height: 92
        radius: 0
        color: root.isTransactionSelected(mobileTransactionCard.rowData) ? root.pale : rowIndex % 2 ? root.tableRowAlt : root.panel
        border.width: 1
        border.color: root.line

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 52
            radius: 0
            color: !mobileTransactionCard.rowData ? root.line : mobileTransactionCard.rowData.type === "transfer" ? root.navSelected : (mobileTransactionCard.rowData.type === "income" || (mobileTransactionCard.rowData.type === "investment_cash" && mobileTransactionCard.rowData.amount >= 0)) ? root.income : root.red
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 8
            anchors.topMargin: 9
            anchors.bottomMargin: 9
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileText {
                        font.family: MobileTheme.sans
                        text: mobileTransactionCard.rowData ? root.transactionTypeLabel(mobileTransactionCard.rowData) : ""
                        color: root.accent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    MobileText {
                        font.family: MobileTheme.sans
                        Layout.fillWidth: true
                        text: mobileTransactionCard.rowData ? mobileTransactionCard.rowData.categoryName : ""
                        color: root.muted
                        font.pixelSize: 16
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                    }
                }

                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: mobileTransactionCard.rowData ? root.transactionSummary(mobileTransactionCard.rowData) : ""
                    color: root.accent
                    font.pixelSize: 16
                    elide: Text.ElideRight
                }

                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: mobileTransactionCard.rowData ? root.accountName(mobileTransactionCard.rowData.accountId) + " · " + Qt.formatDateTime(new Date(mobileTransactionCard.rowData.date), "dd.MM.yyyy") : ""
                    color: root.muted
                    font.pixelSize: 16
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.preferredWidth: Math.min(130, mobileTransactionCard.width * 0.38)
                Layout.fillHeight: true
                spacing: 0

                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: mobileTransactionCard.rowData ? root.money(root.transactionSignedAmount(mobileTransactionCard.rowData), mobileTransactionCard.rowData.currency, true) : ""
                    color: !mobileTransactionCard.rowData ? root.accent : mobileTransactionCard.rowData.type === "transfer" ? root.navSelected : (mobileTransactionCard.rowData.type === "income" || (mobileTransactionCard.rowData.type === "investment_cash" && mobileTransactionCard.rowData.amount >= 0)) ? root.income : root.red
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }

                SoftButton {
                    id: transactionMoreButton
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: 42
                    implicitHeight: 36
                    flat: true
                    text: "⋮"
                    font.pixelSize: 22
                    onClicked: {
                        if (mobileTransactionCard.rowData)
                            root.openTransactionContextMenu(mobileTransactionCard.rowData, transactionMoreButton, transactionMoreButton.width / 2, transactionMoreButton.height / 2);
                    }
                }
            }
        }

        MouseArea {
            id: transactionTouchArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: 50
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // A long press selects the operation; the click that may follow its release is then ignored
            property bool holdHandled: false
            onPressAndHold: {
                holdHandled = true;
                root.toggleTransactionSelection(mobileTransactionCard.rowData);
            }
            onClicked: function (mouse) {
                if (mouse.button !== Qt.LeftButton || holdHandled)
                    return;
                if (root.transactionSelectionCount > 0)
                    root.toggleTransactionSelection(mobileTransactionCard.rowData);
                else if (mobileTransactionCard.rowData)
                    root.openTransactionContextMenu(mobileTransactionCard.rowData, transactionTouchArea, mouseX, mouseY);
            }
            onPressed: function (mouse) {
                holdHandled = false;
                if (mouse.button === Qt.RightButton && mobileTransactionCard.rowData)
                    root.openTransactionContextMenu(mobileTransactionCard.rowData, transactionTouchArea, mouse.x, mouse.y);
            }
        }
    }

    component MobileTransactionList: Item {
        id: mobileTransactionList
        property var rows: []
        property bool expandToContent: false

        Column {
            anchors.fill: parent
            spacing: 8
            visible: mobileTransactionList.expandToContent

            Repeater {
                model: mobileTransactionList.rows
                delegate: MobileTransactionCard {
                    required property int index
                    required property var modelData
                    width: parent.width
                    rowData: modelData
                    rowIndex: index
                }
            }
        }

        ListView {
            anchors.fill: parent
            visible: !mobileTransactionList.expandToContent
            clip: true
            spacing: 8
            model: mobileTransactionList.rows
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }

            delegate: MobileTransactionCard {
                required property int index
                required property var modelData
                width: ListView.view.width
                rowData: modelData
                rowIndex: index
            }
        }

        Label {
            anchors.centerIn: parent
            visible: mobileTransactionList.rows.length === 0
            text: qsTr("Операций пока нет")
            color: root.muted
        }
    }

    component MobileTransactionBlock: Panel {
        id: mobileTransactionBlock
        property string title: qsTr("История операций")
        property var rows: []
        property bool expandToContent: false

        implicitHeight: expandToContent ? 72 + Math.max(72, rows.length * 98) : 260

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: mobileTransactionBlock.title
                    color: root.accent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                SoftButton {
                    text: qsTr("+ Операция")
                    highlighted: true
                    implicitWidth: 122
                    onClicked: root.openNewOperation()
                }
            }

            MobileTransactionList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                rows: mobileTransactionBlock.rows
                expandToContent: mobileTransactionBlock.expandToContent
            }
        }
    }

    Component {
        id: accountsPage
        ColumnLayout {
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.assets
                        delegate: SoftButton {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: modelData.title
                            highlighted: financeController.selectedAsset === modelData.code
                            onClicked: financeController.selectedAsset = modelData.code
                        }
                    }
                }

                SoftButton {
                    Layout.fillWidth: true
                    visible: financeController.selectedAsset !== "investment" || financeController.investmentAccounts.length > 0
                    text: financeController.selectedAsset === "crypto" ? qsTr("+ Добавить криптовалюту") : financeController.selectedAsset === "investment" ? qsTr("+ Добавить позицию") : qsTr("+ Добавить счёт")
                    highlighted: true
                    onClicked: {
                        if (financeController.selectedAsset === "crypto")
                            cryptoWalletDialog.openForNewWallet();
                        else if (financeController.selectedAsset === "investment")
                            investmentPositionDialog.openForNewPosition();
                        else
                            accountDialog.openForSelectedAsset();
                    }
                }
                SoftButton {
                    Layout.fillWidth: true
                    visible: financeController.selectedAsset === "investment"
                    text: qsTr("+ Добавить счёт")
                    onClicked: accountDialog.openForSelectedAsset()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: financeController.selectedAsset === "crypto" && (financeController.cryptoRefreshing || financeController.cryptoLastError.length > 0)

                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: financeController.cryptoRefreshing ? qsTr("Обновляем балансы, цены и историю криптовалют…") : qsTr("Не удалось обновить криптоданные: %1").arg(financeController.cryptoLastError)
                    color: financeController.cryptoRefreshing ? root.muted : root.red
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                }
                SoftButton {
                    Layout.fillWidth: true
                    visible: !financeController.cryptoRefreshing
                    text: qsTr("Повторить")
                    onClicked: financeController.refreshCryptoWallets()
                }
            }

            Panel {
                id: cryptoHistoryPanel
                Layout.fillWidth: true
                visible: financeController.selectedAsset === "crypto" && cryptoHistoryRows.length > 0
                implicitHeight: cryptoHistoryColumn.implicitHeight + 28
                // The newest operations first; the list stays short on a phone
                readonly property var cryptoHistoryRows: (financeController.cryptoTransactions || []).slice(0, 50)
                ColumnLayout {
                    id: cryptoHistoryColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Операции криптовалюты")
                        color: root.accent
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    MobileText {
                        font.family: MobileTheme.mono
                        Layout.fillWidth: true
                        text: qsTr("Долгое нажатие на операцию удаляет её из истории")
                        color: root.muted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: cryptoHistoryPanel.cryptoHistoryRows
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: cryptoRow.implicitHeight + 8
                            radius: 0
                            color: root.isTransactionSelected(modelData) ? root.pale : "transparent"

                            RowLayout {
                                id: cryptoRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                MobileText {
                                    font.family: MobileTheme.mono
                                    text: Qt.formatDateTime(modelData.occurredAt, "dd.MM.yy HH:mm")
                                    color: root.muted
                                    font.pixelSize: 12
                                }
                                MobileText {
                                    font.family: MobileTheme.sans
                                    Layout.fillWidth: true
                                    text: modelData.counterparty
                                    color: root.accent
                                    font.pixelSize: 16
                                    elide: Text.ElideMiddle
                                }
                                MobileText {
                                    font.family: MobileTheme.sans
                                    text: (modelData.direction === "in" ? "+" : modelData.direction === "out" ? "−" : "") + String(modelData.amountText).replace(".", ",") + " " + modelData.symbol
                                    color: modelData.direction === "in" ? root.income : root.accent
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }
                            }
                            TapHandler {
                                onTapped: {
                                    if (root.transactionSelectionCount > 0)
                                        root.toggleTransactionSelection(modelData);
                                }
                                onLongPressed: root.toggleTransactionSelection(modelData)
                            }
                        }
                    }
                }
            }

            Panel {
                id: holdingsPanel
                Layout.fillWidth: true
                visible: financeController.selectedAsset === "crypto" && exchangeRows.length > 0
                implicitHeight: holdingsColumn.implicitHeight + 28
                // Reading cryptoWallets makes the binding follow every refresh of the exchanges
                readonly property var exchangeRows: {
                    financeController.cryptoWallets;
                    return financeController.cryptoExchangeHoldings();
                }
                ColumnLayout {
                    id: holdingsColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Остатки на бирже")
                        color: root.accent
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: holdingsPanel.exchangeRows
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            MobileText {
                                font.family: MobileTheme.sans
                                Layout.fillWidth: true
                                text: modelData.accountName + " · " + root.exchangeSection(modelData.section) + (modelData.category ? " · " + modelData.category : "")
                                color: root.accent
                                font.pixelSize: 16
                                font.weight: modelData.summary ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                            MobileText {
                                font.family: MobileTheme.sans
                                text: modelData.summary ? Number(modelData.usdValue).toLocaleString(MobileFormat.locale(), "f", 2) + " $" : String(modelData.amountText) + " " + modelData.coin
                                color: root.accent
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: financeController.selectedAsset !== "investment"
                Layout.preferredHeight: financeController.selectedAsset === "investment" ? Math.min(contentHeight, 300) : -1
                Layout.minimumHeight: financeController.selectedAsset === "investment" ? Math.min(Math.max(contentHeight, 148), 300) : 0
                clip: true
                spacing: 12
                // Scrollbars intentionally hidden application-wide.
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }
                model: financeController.selectedAsset === "crypto" ? financeController.cryptoWallets : financeController.accounts
                delegate: Panel {
                    required property var modelData
                    width: ListView.view.width
                    height: modelData.isCrypto ? 174 : 138
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 54
                        anchors.topMargin: 16
                        anchors.bottomMargin: 16
                        RowLayout {
                            MobileText {
                                font.family: MobileTheme.serif
                                text: "▣"
                                color: root.accent
                                font.pixelSize: 24
                            }
                            MobileText {
                                font.family: MobileTheme.sans
                                Layout.fillWidth: true
                                text: modelData.name
                                color: root.accent
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                        MobileText {
                            Layout.fillWidth: true
                            text: root.accountPrimaryAmount(modelData)
                            color: root.accent
                            font.pixelSize: modelData.isCreditCard ? 18 : 23
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        MobileText {
                            font.family: MobileTheme.sans
                            Layout.fillWidth: true
                            visible: modelData.isCreditCard
                            text: root.accountAvailableCredit(modelData)
                            color: root.navSelected
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }
                        MobileText {
                            font.family: MobileTheme.sans
                            Layout.fillWidth: true
                            visible: modelData.isCrypto
                            text: "≈ " + root.money(modelData.valueMinor, financeController.appCurrency, false)
                            color: root.navSelected
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }
                        MobileText {
                            font.family: MobileTheme.sans
                            Layout.fillWidth: true
                            text: modelData.isCrypto ? modelData.network + " · " + modelData.address : modelData.currency + " · " + root.accountTypeLabel(modelData.type)
                            color: root.muted
                            font.pixelSize: 16
                            elide: Text.ElideMiddle
                        }
                        MobileText {
                            font.family: MobileTheme.sans
                            Layout.fillWidth: true
                            visible: modelData.isCrypto
                            text: root.cryptoWalletStatus(modelData)
                            color: modelData.refreshing ? root.navSelected : root.muted
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: accountsPageMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: 48
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPressAndHold: root.openAccountContextMenu(modelData, accountsPageMouseArea, mouseX, mouseY)
                        onPressed: function (mouse) {
                            if (mouse.button === Qt.RightButton)
                                root.openAccountContextMenu(modelData, accountsPageMouseArea, mouse.x, mouse.y);
                        }
                    }

                    SoftButton {
                        id: accountMoreButton
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        width: 42
                        height: 42
                        flat: true
                        text: "⋮"
                        font.pixelSize: 22
                        onClicked: root.openAccountContextMenu(modelData, accountMoreButton, width / 2, height / 2)
                    }
                }
                Label {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: financeController.selectedAsset === "crypto" ? qsTr("Добавьте публичный адрес криптокошелька") : qsTr("У этого актива пока нет счетов")
                    color: root.muted
                }
            }
            InvestmentPositionsPanel {
                visible: financeController.selectedAsset === "investment"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 260
                controller: financeController
                showEditButton: true
                onOperationRequested: function (position) {
                    investmentOperationDialog.openFor(position);
                }
                onEditRequested: function (position) {
                    investmentPositionDialog.openForEdit(position);
                }
                panelColor: root.panel
                textColor: root.accent
                mutedColor: root.muted
                lineColor: root.line
                errorColor: root.red
            }
        }
    }

    Component {
        id: categoriesPage
        MobileCategoriesPage {
            id: categoryPage
            host: root
            Connections {
                target: root
                function onCreateRequested(key) {
                    if (key === "categories")
                        categoryPage.create();
                }
            }
        }
    }

    Component {
        id: operationsPage
        MobileTransactionBlock {
            anchors.fill: parent
            title: qsTr("История операций")
            rows: root.visibleTransactions()
        }
    }

    Component {
        id: analyticsPage

        MobileAnalyticsPage {}
    }
    Component {
        id: settingsPage
        Panel {
            ScrollView {
                id: settingsScroll
                anchors.fill: parent
                clip: true
                contentWidth: availableWidth
                contentHeight: settingsContent.implicitHeight + 32
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }

                ColumnLayout {
                    id: settingsContent
                    x: 16
                    y: 16
                    width: Math.max(0, settingsScroll.availableWidth - 32)
                    DatabaseEncryptionSettings {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 24
                    }
                    PasswordSettings {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 24
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        Layout.fillWidth: true
                        text: qsTr("Основная валюта")
                        color: root.accent
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    MobileText {
                        Layout.fillWidth: true
                        text: qsTr("Все итоговые суммы пересчитываются в эту валюту.")
                        color: root.muted
                        wrapMode: Text.WordWrap
                    }
                    AppComboBox {
                        Layout.fillWidth: true
                        model: ["RUB", "USD", "EUR", "CNY"]
                        currentIndex: Math.max(0, model.indexOf(financeController.appCurrency))
                        onActivated: financeController.appCurrency = currentText
                    }
                    Rectangle {
                        Layout.topMargin: 12
                        Layout.fillWidth: true
                        height: 1
                        color: root.line
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        Layout.topMargin: 8
                        text: qsTr("Курсы валют")
                        color: root.accent
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    MobileText {
                        Layout.fillWidth: true
                        text: automaticRatesCheck.checked ? qsTr("Курсы загружаются из ЦБ РФ дважды в сутки. При ошибке используется последний успешный результат.") : qsTr("Автоматические запросы отключены. Для пересчёта используются сохранённые ниже значения.")
                        color: root.muted
                        wrapMode: Text.WordWrap
                    }
                    Rectangle {
                        id: currentRatesBlock
                        HardShadow {}

                        Layout.topMargin: 4
                        Layout.fillWidth: true
                        implicitHeight: ratesHeader.height + ratesList.implicitHeight
                        radius: 0
                        color: root.soft
                        border.color: root.line
                        clip: true

                        Rectangle {
                            id: ratesHeader
                            width: parent.width
                            height: 44
                            color: root.transparentColor

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                MobileText {
                                    Layout.fillWidth: true
                                    text: qsTr("Текущие курсы в %1").arg("RUB")
                                    color: root.accent
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Column {
                            id: ratesList
                            anchors.top: ratesHeader.bottom
                            width: parent.width

                            Repeater {
                                model: financeController.currentCurrencyRates

                                Rectangle {
                                    required property var modelData
                                    width: ratesList.width
                                    height: 38
                                    color: root.transparentColor

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        height: 1
                                        color: root.line
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16

                                        MobileText {
                                            Layout.fillWidth: true
                                            text: "1 " + modelData.code
                                            color: root.accent
                                        }
                                        MobileText {
                                            readonly property int decimals: modelData.rate >= 100 ? 2 : modelData.rate >= 1 ? 4 : 6
                                            text: Number(modelData.rate).toLocaleString(root.uiLocale(), "f", decimals) + " " + root.symbol("RUB")
                                            color: root.accent
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }
                        }
                    }
                    AppCheckBox {
                        id: automaticRatesCheck
                        text: qsTr("Обновлять курсы автоматически")
                        checked: financeController.automaticCurrencyRates
                        onToggled: {
                            financeController.automaticCurrencyRates = checked;
                            rateSaveStatus.text = "";
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width < 380 ? 1 : 2
                        columnSpacing: 12
                        rowSpacing: 12
                        enabled: !automaticRatesCheck.checked
                        opacity: enabled ? 1.0 : 0.55

                        MobileText {
                            text: qsTr("1 RUB в рублях")
                            color: root.accent
                        }
                        AppTextField {
                            id: manualRubRateField
                            Layout.fillWidth: true
                            text: financeController.manualRubToRubRate.toLocaleString(root.uiLocale(), "f", 4)
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: DoubleValidator {
                                bottom: 0.0001
                                top: 999999999
                                decimals: 4
                                locale: root.uiLocale().name
                            }
                            onTextEdited: rateSaveStatus.text = ""
                        }

                        MobileText {
                            text: qsTr("1 USD в рублях")
                            color: root.accent
                        }
                        AppTextField {
                            id: manualUsdRateField
                            Layout.fillWidth: true
                            text: financeController.manualUsdToRubRate.toLocaleString(root.uiLocale(), "f", 4)
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: DoubleValidator {
                                bottom: 0.0001
                                top: 999999999
                                decimals: 4
                                locale: root.uiLocale().name
                            }
                            onTextEdited: rateSaveStatus.text = ""
                        }

                        MobileText {
                            text: qsTr("1 EUR в рублях")
                            color: root.accent
                        }
                        AppTextField {
                            id: manualEurRateField
                            Layout.fillWidth: true
                            text: financeController.manualEurToRubRate.toLocaleString(root.uiLocale(), "f", 4)
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: DoubleValidator {
                                bottom: 0.0001
                                top: 999999999
                                decimals: 4
                                locale: root.uiLocale().name
                            }
                            onTextEdited: rateSaveStatus.text = ""
                        }

                        MobileText {
                            text: qsTr("1 CNY в рублях")
                            color: root.accent
                        }
                        AppTextField {
                            id: manualCnyRateField
                            Layout.fillWidth: true
                            text: financeController.manualCnyToRubRate.toLocaleString(root.uiLocale(), "f", 4)
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: DoubleValidator {
                                bottom: 0.0001
                                top: 999999999
                                decimals: 4
                                locale: root.uiLocale().name
                            }
                            onTextEdited: rateSaveStatus.text = ""
                        }
                    }
                    RowLayout {
                        enabled: !automaticRatesCheck.checked
                        opacity: enabled ? 1.0 : 0.55

                        SoftButton {
                            text: qsTr("Сохранить курсы")
                            highlighted: true
                            enabled: manualRubRateField.acceptableInput && manualUsdRateField.acceptableInput && manualEurRateField.acceptableInput && manualCnyRateField.acceptableInput
                            onClicked: {
                                const rubRate = Number(manualRubRateField.text.replace(",", "."));
                                const usdRate = Number(manualUsdRateField.text.replace(",", "."));
                                const eurRate = Number(manualEurRateField.text.replace(",", "."));
                                const cnyRate = Number(manualCnyRateField.text.replace(",", "."));
                                const saved = financeController.saveManualCurrencyRates(rubRate, usdRate, eurRate, cnyRate);
                                rateSaveStatus.color = saved ? root.income : root.red;
                                rateSaveStatus.text = saved ? qsTr("Курсы сохранены") : qsTr("Введите положительные числовые значения");
                            }
                        }
                        MobileText {
                            id: rateSaveStatus
                            font.family: MobileTheme.sans
                            Layout.fillWidth: true
                            color: root.income
                            font.pixelSize: 16
                            wrapMode: Text.WordWrap
                        }
                    }
                    Rectangle {
                        Layout.topMargin: 12
                        Layout.fillWidth: true
                        height: 1
                        color: root.line
                    }
                    MobileText {
                        font.family: MobileTheme.sans
                        Layout.topMargin: 8
                        text: qsTr("Язык интерфейса")
                        color: root.accent
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    MobileText {
                        Layout.fillWidth: true
                        text: qsTr("Пользовательские названия счетов и категорий не переводятся.")
                        color: root.muted
                        wrapMode: Text.WordWrap
                    }
                    AppComboBox {
                        id: languageBox
                        Layout.fillWidth: true
                        model: [
                            {
                                label: qsTr("Русский"),
                                value: "ru"
                            },
                            {
                                label: qsTr("Английский"),
                                value: "en"
                            }
                        ]
                        textRole: "label"
                        currentIndex: root.indexByRole(model, "value", financeController.uiLanguage)
                        onActivated: financeController.uiLanguage = model[currentIndex].value
                    }
                    Item {
                        Layout.preferredHeight: 4
                    }
                }
            }
        }
    }

    BankCsvImportDialog {
        id: bankCsvImportDialog
        controller: financeController
        panelColor: root.panel
        softColor: root.soft
        textColor: root.accent
        mutedColor: root.muted
        lineColor: root.line
        accentColor: root.accent
        errorColor: root.red
        successColor: root.income
    }

    MobileSheet {
        id: transactionDeleteSheet

        title: qsTr("Удалить операции?")
        property string errorText: ""

        function openFor() {
            errorText = "";
            if (root.transactionSelectionCount > 0)
                open();
        }

        MobileText {
            font.family: MobileTheme.sans
            Layout.fillWidth: true
            text: qsTr("Выделено операций: %1").arg(root.transactionSelectionCount)
            color: root.accent
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
        MobileText {
            font.family: MobileTheme.sans
            Layout.fillWidth: true
            text: qsTr("Переводы будут удалены вместе с парной операцией.")
            color: root.muted
            font.pixelSize: 16
            wrapMode: Text.WordWrap
        }
        MobileText {
            font.family: MobileTheme.sans
            Layout.fillWidth: true
            visible: transactionDeleteSheet.errorText.length > 0
            text: transactionDeleteSheet.errorText
            color: root.red
            font.pixelSize: 16
            wrapMode: Text.WordWrap
        }
        MobileButton {
            Layout.fillWidth: true
            variant: "danger"
            text: qsTr("Удалить")
            onClicked: {
                if (financeController.deleteHistoryRows(root.selectedTransactionRows())) {
                    root.clearTransactionSelection();
                    transactionDeleteSheet.close();
                } else {
                    transactionDeleteSheet.errorText = qsTr("Не удалось удалить операции. Данные не изменены.");
                }
            }
        }
        MobileButton {
            Layout.fillWidth: true
            text: qsTr("Отмена")
            onClicked: transactionDeleteSheet.close()
        }
    }

    BrokerOperationDialog {
        id: brokerOperationDialog
        controller: financeController
        panelColor: root.panel
        softColor: root.soft
        textColor: root.accent
        mutedColor: root.muted
        lineColor: root.line
        accentColor: root.accent
        hoverColor: root.pale
        errorColor: root.red
    }

    InvestmentOperationDialog {
        id: investmentOperationDialog
        controller: financeController
        panelColor: root.panel
        softColor: root.soft
        textColor: root.accent
        mutedColor: root.muted
        lineColor: root.line
        accentColor: root.accent
        errorColor: root.red
    }

    InvestmentPositionDialog {
        id: investmentPositionDialog
        controller: financeController
        panelColor: root.panel
        textColor: root.accent
        mutedColor: root.muted
        lineColor: root.line
        accentColor: root.accent
        errorColor: root.red
    }

    EditorialDialog {
        id: cryptoWalletDialog
        width: Math.min(500, root.width - 20)
        modal: true
        anchors.centerIn: parent
        padding: root.width < 380 ? 16 : 20
        property string editingId: ""

        function openForNewWallet() {
            editingId = "";
            cryptoNameField.clear();
            cryptoSourceBox.currentIndex = 0;
            cryptoTypeBox.currentIndex = 0;
            cryptoAddressField.clear();
            cryptoApiKeyField.clear();
            cryptoApiSecretField.clear();
            cryptoWalletError.text = "";
            open();
            cryptoNameField.forceActiveFocus();
        }

        function submit() {
            const result = financeController.saveCryptoConnection({
                id: editingId,
                name: cryptoNameField.text,
                kind: cryptoSourceBox.currentIndex === 0 ? "wallet" : "exchange",
                symbol: cryptoTypeBox.model[cryptoTypeBox.currentIndex].value,
                address: cryptoAddressField.text,
                apiKey: cryptoApiKeyField.text,
                apiSecret: cryptoApiSecretField.text
            });
            if (result.ok)
                close();
            else
                cryptoWalletError.text = result.error || qsTr("Не удалось сохранить счёт");
        }

        onClosed: {
            cryptoApiKeyField.clear();
            cryptoApiSecretField.clear();
        }

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }

        contentItem: EditorialDialogForm {
            spacing: 16

            EditorialDialogTitle {
                text: qsTr("Добавить криптовалюту")
                color: root.accent
            }
            AppTextField {
                id: cryptoNameField
                Layout.fillWidth: true
                placeholderText: qsTr("Название счёта")
                maximumLength: 80
            }
            AppComboBox {
                id: cryptoSourceBox
                Layout.fillWidth: true
                model: [
                    {
                        label: qsTr("Кошелёк по публичному адресу"),
                        value: "wallet"
                    },
                    {
                        label: qsTr("Биржа Bybit"),
                        value: "exchange"
                    }
                ]
                textRole: "label"
                onActivated: cryptoWalletError.text = ""
            }
            AppComboBox {
                id: cryptoTypeBox
                Layout.fillWidth: true
                visible: cryptoSourceBox.currentIndex === 0
                model: [
                    {
                        label: "USDT · TRC-20",
                        value: "USDT"
                    },
                    {
                        label: "BTC · Bitcoin",
                        value: "BTC"
                    },
                    {
                        label: "ETH · Ethereum",
                        value: "ETH"
                    }
                ]
                textRole: "label"
                onActivated: {
                    cryptoAddressField.clear();
                    cryptoWalletError.text = "";
                    cryptoAddressField.forceActiveFocus();
                }
            }
            AppTextField {
                id: cryptoAddressField
                Layout.fillWidth: true
                visible: cryptoSourceBox.currentIndex === 0
                placeholderText: cryptoTypeBox.currentIndex === 0 ? qsTr("Публичный адрес TRON (T…)") : cryptoTypeBox.currentIndex === 1 ? qsTr("Публичный адрес Bitcoin (1…, 3… или bc1…)") : qsTr("Публичный адрес Ethereum (0x…)")
                maximumLength: 90
                onAccepted: cryptoWalletDialog.submit()
            }
            AppTextField {
                id: cryptoApiKeyField
                Layout.fillWidth: true
                visible: cryptoSourceBox.currentIndex === 1
                placeholderText: qsTr("Ключ API")
                maximumLength: 256
                echoMode: TextInput.Password
            }
            AppTextField {
                id: cryptoApiSecretField
                Layout.fillWidth: true
                visible: cryptoSourceBox.currentIndex === 1
                placeholderText: qsTr("Секретный ключ")
                maximumLength: 256
                echoMode: TextInput.Password
                onAccepted: cryptoWalletDialog.submit()
            }
            MobileText {
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                text: cryptoSourceBox.currentIndex === 0 ? qsTr("Вводите только публичный адрес. Никогда не указывайте seed-фразу или приватный ключ.") : qsTr("Bybit: основной сайт, ключ с доступом только на чтение. История торгового счёта и финансирования загружается автоматически.")
                color: root.muted
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }
            MobileText {
                id: cryptoWalletError
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                color: root.red
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                SoftButton {
                    text: qsTr("Отмена")
                    onClicked: cryptoWalletDialog.close()
                }
                SoftButton {
                    text: qsTr("Добавить")
                    highlighted: true
                    onClicked: cryptoWalletDialog.submit()
                }
            }
        }
    }

    EditorialDialog {
        id: accountDialog
        width: Math.min(500, root.width - 20)
        height: Math.min(700, root.height - 24)
        modal: true
        anchors.centerIn: parent
        padding: root.width < 380 ? 16 : 20
        property var accountTypes: []
        property string editingId: ""
        property var editingAccount: null
        property bool countsDebtChecked: true
        property string editingAsset: financeController.selectedAsset
        property var depositPayoutTypes: [
            {
                label: qsTr("Ежемесячно"),
                value: "monthly"
            },
            {
                label: qsTr("Ежедневно"),
                value: "daily"
            }
        ]
        readonly property bool creditCardSelected: accountTypeBox.currentIndex >= 0 && accountTypeBox.currentIndex < accountTypes.length && accountTypes[accountTypeBox.currentIndex].value === "credit_card"
        readonly property bool depositSelected: accountTypeBox.currentIndex >= 0 && accountTypeBox.currentIndex < accountTypes.length && accountTypes[accountTypeBox.currentIndex].value === "deposit"
        readonly property bool monthlyDepositSelected: depositSelected && depositPayoutBox.currentIndex === 0

        function typesForAsset(asset) {
            return asset === "fiat" ? [
                {
                    label: qsTr("Наличные"),
                    value: "cash"
                },
                {
                    label: qsTr("Дебетовая карта"),
                    value: "debit_card"
                },
                {
                    label: qsTr("Кредитная карта"),
                    value: "credit_card"
                },
                {
                    label: qsTr("Другой"),
                    value: "other"
                }
            ] : asset === "crypto" ? [
                {
                    label: qsTr("Криптокошелёк"),
                    value: "crypto_wallet"
                },
                {
                    label: qsTr("Другой"),
                    value: "other"
                }
            ] : [
                {
                    label: qsTr("Брокер"),
                    value: "brokerage"
                },
                {
                    label: qsTr("Вклад"),
                    value: "deposit"
                },
                {
                    label: qsTr("Другой"),
                    value: "other"
                }
            ];
        }

        function openForSelectedAsset() {
            editingId = "";
            editingAccount = null;
            editingAsset = financeController.selectedAsset;
            accountTypes = typesForAsset(editingAsset);
            accountNameField.clear();
            accountBalanceField.clear();
            accountCreditLimitField.clear();
            countsDebtChecked = true;
            depositRateField.clear();
            depositPayoutBox.currentIndex = 0;
            depositPayoutDayField.text = "1";
            accountTypeBox.currentIndex = 0;
            accountCurrencyBox.currentIndex = 0;
            accountError.text = "";
            open();
        }

        function openForEdit(row) {
            editingId = row.id;
            editingAccount = row;
            editingAsset = row.asset;
            accountTypes = typesForAsset(editingAsset);
            accountNameField.text = row.name;
            accountTypeBox.currentIndex = root.indexByRole(accountTypes, "value", row.type);
            accountCurrencyBox.currentIndex = Math.max(0, accountCurrencyBox.model.indexOf(row.currency));
            accountBalanceField.text = row.isCreditCard ? root.amountForInput(row.initialDebtMinor) : root.signedAmountForInput(row.initialBalanceMinor);
            accountCreditLimitField.text = root.amountForInput(row.creditLimitMinor);
            countsDebtChecked = row.countsDebt !== false;
            depositRateField.text = row.depositAnnualRatePercent ? String(row.depositAnnualRatePercent).replace(".", ",") : "";
            depositPayoutBox.currentIndex = row.depositPayoutFrequency === "daily" ? 1 : 0;
            depositPayoutDayField.text = row.depositPayoutDay > 0 ? String(row.depositPayoutDay) : "1";
            accountError.text = "";
            open();
        }

        onClosed: {
            editingId = "";
            editingAccount = null;
        }

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }
        contentItem: ScrollView {
            id: accountDialogScroll
            clip: true
            contentWidth: availableWidth
            contentHeight: accountDialogForm.implicitHeight
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }

            ColumnLayout {
                id: accountDialogForm
                width: accountDialogScroll.availableWidth
                spacing: 16
                EditorialDialogTitle {
                    text: (accountDialog.editingId ? qsTr("Редактирование счёта") : qsTr("Новый счёт")) + " · " + root.assetTitle(accountDialog.editingAsset)
                    color: root.accent
                }
                AppTextField {
                    id: accountNameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Название счёта")
                }
                AppComboBox {
                    id: accountTypeBox
                    Layout.fillWidth: true
                    model: accountDialog.accountTypes
                    textRole: "label"
                }
                AppComboBox {
                    id: accountCurrencyBox
                    Layout.fillWidth: true
                    model: ["RUB", "USD", "EUR", "CNY"]
                    enabled: !accountDialog.editingId || !accountDialog.editingAccount || accountDialog.editingAccount.transactionCount === 0
                }
                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    visible: accountDialog.editingId && accountDialog.editingAccount && accountDialog.editingAccount.transactionCount > 0
                    text: qsTr("Валюту счёта с операциями изменить нельзя")
                    color: root.muted
                    font.pixelSize: 16
                }
                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    visible: accountDialog.creditCardSelected
                    text: qsTr("Кредитный лимит")
                    color: root.muted
                    font.pixelSize: 16
                }
                AppTextField {
                    id: accountCreditLimitField
                    Layout.fillWidth: true
                    visible: accountDialog.creditCardSelected
                    placeholderText: qsTr("Кредитный лимит")
                    validator: DoubleValidator {
                        bottom: 0.01
                        top: 999999999
                        decimals: 2
                    }
                }
                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: accountDialog.creditCardSelected ? qsTr("Задолженность на момент добавления") : accountDialog.depositSelected ? qsTr("Сумма вклада") : accountTypeBox.currentIndex >= 0 && accountTypeBox.currentIndex < accountDialog.accountTypes.length && accountDialog.accountTypes[accountTypeBox.currentIndex].value === "brokerage" ? qsTr("Деньги на счёте, включая обеспечение") : qsTr("Начальный баланс")
                    color: root.muted
                    font.pixelSize: 16
                }
                AppTextField {
                    id: accountBalanceField
                    Layout.fillWidth: true
                    placeholderText: accountDialog.creditCardSelected ? qsTr("Задолженность на момент добавления") : accountDialog.depositSelected ? qsTr("Сумма вклада") : accountTypeBox.currentIndex >= 0 && accountTypeBox.currentIndex < accountDialog.accountTypes.length && accountDialog.accountTypes[accountTypeBox.currentIndex].value === "brokerage" ? qsTr("Деньги на счёте, включая обеспечение") : qsTr("Начальный баланс")
                    validator: DoubleValidator {
                        bottom: accountDialog.creditCardSelected || accountDialog.depositSelected ? 0 : -999999999
                        top: 999999999
                        decimals: 2
                    }
                }
                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    visible: accountDialog.depositSelected
                    text: qsTr("Годовая ставка, %")
                    color: root.muted
                    font.pixelSize: 16
                }
                AppTextField {
                    id: depositRateField
                    Layout.fillWidth: true
                    visible: accountDialog.depositSelected
                    placeholderText: qsTr("Например, 13")
                    validator: DoubleValidator {
                        bottom: 0.01
                        top: 1000
                        decimals: 2
                    }
                }
                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    visible: accountDialog.depositSelected
                    text: qsTr("Начисление процентов")
                    color: root.muted
                    font.pixelSize: 16
                }
                AppComboBox {
                    id: depositPayoutBox
                    Layout.fillWidth: true
                    visible: accountDialog.depositSelected
                    model: accountDialog.depositPayoutTypes
                    textRole: "label"
                }
                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    visible: accountDialog.monthlyDepositSelected
                    text: qsTr("День выплаты")
                    color: root.muted
                    font.pixelSize: 16
                }
                AppTextField {
                    id: depositPayoutDayField
                    Layout.fillWidth: true
                    visible: accountDialog.monthlyDepositSelected
                    placeholderText: qsTr("От 1 до 31")
                    validator: IntValidator {
                        bottom: 1
                        top: 31
                    }
                }
                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    visible: accountDialog.creditCardSelected
                    text: qsTr("Кредитный лимит не считается активом. Расходы увеличивают задолженность, а перевод на кредитку её погашает.")
                    color: root.muted
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                }
                MobileCheckRow {
                    Layout.fillWidth: true
                    visible: accountDialog.creditCardSelected
                    label: qsTr("Учитывать долг?")
                    checked: accountDialog.countsDebtChecked
                    onToggled: function (nowChecked) {
                        accountDialog.countsDebtChecked = nowChecked;
                    }
                }
                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    visible: accountDialog.creditCardSelected && !accountDialog.countsDebtChecked
                    text: qsTr("Долг не учитывается нигде: ни в суммах, ни в целях и траектории. В них входит только положительный остаток карты.")
                    color: root.muted
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                }
                MobileText {
                    id: accountError
                    font.family: MobileTheme.sans
                    color: root.red
                    font.pixelSize: 16
                }
                RowLayout {
                    Item {
                        Layout.fillWidth: true
                    }
                    SoftButton {
                        text: qsTr("Отмена")
                        onClicked: accountDialog.close()
                    }
                    SoftButton {
                        text: accountDialog.editingId ? qsTr("Сохранить") : qsTr("Добавить")
                        highlighted: true
                        onClicked: {
                            const type = accountDialog.accountTypes[accountTypeBox.currentIndex].value;
                            const enteredMinor = Math.round((Number(accountBalanceField.text.replace(",", ".")) || 0) * 100);
                            const initialBalanceMinor = accountDialog.creditCardSelected ? -Math.abs(enteredMinor) : enteredMinor;
                            const creditLimitMinor = accountDialog.creditCardSelected ? Math.round((Number(accountCreditLimitField.text.replace(",", ".")) || 0) * 100) : 0;
                            if (accountDialog.creditCardSelected && creditLimitMinor <= 0) {
                                accountError.text = qsTr("Укажите кредитный лимит");
                                return;
                            }
                            const depositAnnualRatePercent = Number(depositRateField.text.replace(",", "."));
                            const depositPayoutFrequency = accountDialog.depositSelected ? accountDialog.depositPayoutTypes[depositPayoutBox.currentIndex].value : "";
                            const depositPayoutDay = accountDialog.monthlyDepositSelected ? Number(depositPayoutDayField.text) : 0;
                            if (accountDialog.depositSelected && initialBalanceMinor <= 0) {
                                accountError.text = qsTr("Укажите сумму вклада");
                                return;
                            }
                            if (accountDialog.depositSelected && depositAnnualRatePercent <= 0) {
                                accountError.text = qsTr("Укажите годовую процентную ставку");
                                return;
                            }
                            if (accountDialog.monthlyDepositSelected && (depositPayoutDay < 1 || depositPayoutDay > 31)) {
                                accountError.text = qsTr("Укажите день выплаты от 1 до 31");
                                return;
                            }
                            const ok = accountDialog.editingId ? financeController.updateAccount(accountDialog.editingId, accountNameField.text, type, accountCurrencyBox.currentText, initialBalanceMinor, creditLimitMinor, depositAnnualRatePercent, depositPayoutFrequency, depositPayoutDay, accountDialog.creditCardSelected ? accountDialog.countsDebtChecked : true) : financeController.addAccount(accountNameField.text, type, accountCurrencyBox.currentText, initialBalanceMinor, creditLimitMinor, depositAnnualRatePercent, depositPayoutFrequency, depositPayoutDay, accountDialog.creditCardSelected ? accountDialog.countsDebtChecked : true);
                            if (ok)
                                accountDialog.close();
                            else
                                accountError.text = qsTr("Проверьте название и параметры счёта");
                        }
                    }
                }
            }
        }
    }

    Menu {
        id: accountContextMenu
        width: 224
        padding: 6
        property var accountData: null
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        AppMenuItem {
            width: accountContextMenu.availableWidth
            text: qsTr("Редактировать")
            visible: accountContextMenu.accountData !== null && !accountContextMenu.accountData.isCrypto
            enabled: visible
            onTriggered: {
                if (accountContextMenu.accountData)
                    accountDialog.openForEdit(accountContextMenu.accountData);
            }
        }

        MenuSeparator {
            width: accountContextMenu.availableWidth
            visible: accountContextMenu.accountData !== null && !accountContextMenu.accountData.isCrypto
            topPadding: 4
            bottomPadding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: root.line
            }
        }

        AppMenuItem {
            width: accountContextMenu.availableWidth
            text: qsTr("Удалить")
            destructive: true
            enabled: accountContextMenu.accountData !== null
            onTriggered: {
                if (accountContextMenu.accountData)
                    deleteAccountDialog.openFor(accountContextMenu.accountData);
            }
        }

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }
    }

    EditorialDialog {
        id: deleteAccountDialog
        width: Math.min(460, root.width - 20)
        modal: true
        anchors.centerIn: parent
        padding: root.width < 380 ? 16 : 20
        closePolicy: Popup.CloseOnEscape
        property var accountData: null

        function openFor(row) {
            accountData = row;
            deleteAccountError.text = "";
            open();
        }

        onClosed: accountData = null

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }

        contentItem: EditorialDialogForm {
            spacing: 16

            EditorialDialogTitle {
                text: deleteAccountDialog.accountData && deleteAccountDialog.accountData.isCrypto ? qsTr("Удалить криптовалюту?") : qsTr("Удалить счёт?")
                color: root.accent
            }

            MobileText {
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                text: deleteAccountDialog.accountData && deleteAccountDialog.accountData.isCrypto ? qsTr("Публичный адрес и сохранённые данные баланса и истории будут удалены. Средства в блокчейне это не затронет.") : deleteAccountDialog.accountData && deleteAccountDialog.accountData.transactionCount > 0 ? qsTr("Счёт и все связанные операции будут удалены. Связанные переводы удалятся целиком. Это действие нельзя отменить.") : qsTr("Счёт будет удалён. Это действие нельзя отменить.")
                color: root.muted
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }

            Panel {
                Layout.fillWidth: true
                implicitHeight: 78
                color: root.soft

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    MobileText {
                        font.family: MobileTheme.sans
                        Layout.fillWidth: true
                        text: deleteAccountDialog.accountData ? deleteAccountDialog.accountData.name : ""
                        color: root.accent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    MobileText {
                        font.family: MobileTheme.sans
                        Layout.fillWidth: true
                        text: deleteAccountDialog.accountData ? root.accountCompactAmount(deleteAccountDialog.accountData) + (deleteAccountDialog.accountData.isCrypto ? "" : " · " + qsTr("операций: ") + deleteAccountDialog.accountData.transactionCount) : ""
                        color: root.muted
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                }
            }

            MobileText {
                id: deleteAccountError
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                color: root.red
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                SoftButton {
                    text: qsTr("Отмена")
                    onClicked: deleteAccountDialog.close()
                }
                SoftButton {
                    text: qsTr("Удалить")
                    destructive: true
                    onClicked: {
                        const row = deleteAccountDialog.accountData;
                        const ok = row && row.isCrypto ? financeController.deleteCryptoWallet(row.id) : row && financeController.deleteAccount(row.id);
                        if (ok)
                            deleteAccountDialog.close();
                        else
                            deleteAccountError.text = row && row.isCrypto ? qsTr("Не удалось удалить криптовалюту") : qsTr("Не удалось удалить счёт");
                    }
                }
            }
        }
    }

    Menu {
        id: transactionContextMenu
        width: 224
        padding: 6
        property var transactionData: null
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        AppMenuItem {
            width: transactionContextMenu.availableWidth
            text: qsTr("Редактировать")
            enabled: transactionContextMenu.transactionData !== null && transactionContextMenu.transactionData.type !== "investment_cash" && !transactionContextMenu.transactionData.investmentTransfer
            onTriggered: {
                if (transactionContextMenu.transactionData)
                    operationDialog.openForEdit(transactionContextMenu.transactionData);
            }
        }

        MenuSeparator {
            width: transactionContextMenu.availableWidth
            topPadding: 4
            bottomPadding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: root.line
            }
        }

        AppMenuItem {
            width: transactionContextMenu.availableWidth
            text: qsTr("Удалить")
            destructive: true
            enabled: transactionContextMenu.transactionData !== null && transactionContextMenu.transactionData.type !== "investment_cash" && !transactionContextMenu.transactionData.investmentTransfer
            onTriggered: {
                if (transactionContextMenu.transactionData)
                    deleteTransactionDialog.openFor(transactionContextMenu.transactionData);
            }
        }

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }
    }

    EditorialDialog {
        id: deleteTransactionDialog
        width: Math.min(460, root.width - 20)
        modal: true
        anchors.centerIn: parent
        padding: root.width < 380 ? 16 : 20
        closePolicy: Popup.CloseOnEscape
        property var transactionData: null

        function openFor(row) {
            transactionData = row;
            deleteTransactionError.text = "";
            open();
        }

        onClosed: transactionData = null

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }

        contentItem: EditorialDialogForm {
            spacing: 16

            EditorialDialogTitle {
                text: qsTr("Удалить операцию?")
                color: root.accent
            }

            MobileText {
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                text: deleteTransactionDialog.transactionData && deleteTransactionDialog.transactionData.type === "transfer" ? qsTr("Будут удалены обе части перевода. Баланс и статистика будут пересчитаны.") : qsTr("Это действие нельзя отменить. Баланс и статистика будут пересчитаны.")
                color: root.muted
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }

            Panel {
                Layout.fillWidth: true
                implicitHeight: 78
                color: root.soft

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    MobileText {
                        font.family: MobileTheme.sans
                        Layout.fillWidth: true
                        text: deleteTransactionDialog.transactionData ? (deleteTransactionDialog.transactionData.description || (deleteTransactionDialog.transactionData.type === "transfer" ? qsTr("Перевод") : deleteTransactionDialog.transactionData.type === "income" ? qsTr("Доход") : qsTr("Расход"))) : ""
                        color: root.accent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    MobileText {
                        font.family: MobileTheme.sans
                        Layout.fillWidth: true
                        text: deleteTransactionDialog.transactionData ? root.accountName(deleteTransactionDialog.transactionData.accountId) + " · " + root.money(root.transactionSignedAmount(deleteTransactionDialog.transactionData), deleteTransactionDialog.transactionData.currency, true) : ""
                        color: root.muted
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                }
            }

            MobileText {
                id: deleteTransactionError
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                color: root.red
                font.pixelSize: 16
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                SoftButton {
                    text: qsTr("Отмена")
                    onClicked: deleteTransactionDialog.close()
                }
                SoftButton {
                    text: qsTr("Удалить")
                    destructive: true
                    onClicked: {
                        const row = deleteTransactionDialog.transactionData;
                        if (row && financeController.deleteTransaction(row.id))
                            deleteTransactionDialog.close();
                        else
                            deleteTransactionError.text = qsTr("Не удалось удалить операцию");
                    }
                }
            }
        }
    }

    EditorialDialog {
        id: operationDialog
        width: Math.min(520, root.width - 20)
        height: Math.min(720, root.height - 24)
        modal: true
        anchors.centerIn: parent
        padding: root.width < 380 ? 16 : 20
        property string editingId: ""
        property var editingTransaction: null
        property string editingSourceAccountId: ""
        property string editingTargetAccountId: ""
        property date selectedDate: new Date()

        function selectDate(day) {
            const time = selectedDate;
            selectedDate = new Date(day.getFullYear(), day.getMonth(), day.getDate(), time.getHours(), time.getMinutes(), time.getSeconds(), time.getMilliseconds());
        }

        function exactIndexByRole(model, role, value) {
            for (let i = 0; i < model.length; ++i)
                if (model[i][role] === value)
                    return i;
            return -1;
        }

        function selectTransferAccounts(sourceId, targetId) {
            const rows = financeController.allAccounts;
            let sourceIndex = exactIndexByRole(rows, "id", sourceId);
            if (sourceIndex < 0)
                sourceIndex = rows.length > 0 ? 0 : -1;
            operationAccount.currentIndex = sourceIndex;

            const resolvedSourceId = sourceIndex >= 0 ? rows[sourceIndex].id : "";
            let targetIndex = exactIndexByRole(rows, "id", targetId);
            if (targetIndex < 0 || rows[targetIndex].id === resolvedSourceId) {
                targetIndex = -1;
                for (let i = 0; i < rows.length; ++i) {
                    if (rows[i].id !== resolvedSourceId) {
                        targetIndex = i;
                        break;
                    }
                }
            }
            transferTargetAccount.currentIndex = targetIndex;
        }

        function openForNew() {
            editingId = "";
            editingTransaction = null;
            editingSourceAccountId = "";
            editingTargetAccountId = "";
            operationError.text = "";
            operationAmount.clear();
            operationDescription.clear();
            selectedDate = new Date();
            operationType.currentIndex = 1;
            operationAccount.currentIndex = root.indexByRole(financeController.accounts, "id", financeController.selectedAccountId);
            // No account is picked on the overview: the new operation goes to the first account of the active asset
            if (operationAccount.currentIndex < 0 && financeController.accounts.length > 0)
                operationAccount.currentIndex = 0;
            operationCategory.currentIndex = 0;
            const source = operationAccount.currentIndex >= 0 ? financeController.accounts[operationAccount.currentIndex] : null;
            const allAccounts = financeController.allAccounts;
            transferTargetAccount.currentIndex = -1;
            for (let i = 0; i < allAccounts.length; ++i) {
                if (!source || allAccounts[i].id !== source.id) {
                    transferTargetAccount.currentIndex = i;
                    break;
                }
            }
            open();
        }

        function openForEdit(row) {
            editingId = row.id;
            editingTransaction = row;
            operationError.text = "";
            const restoredDate = new Date(row.date);
            selectedDate = isNaN(restoredDate.getTime()) ? new Date() : restoredDate;
            if (row.type === "transfer") {
                const details = financeController.transferDetails(row.id);
                editingSourceAccountId = details.sourceAccountId || "";
                editingTargetAccountId = details.targetAccountId || "";
                operationType.currentIndex = 2;
                selectTransferAccounts(editingSourceAccountId, editingTargetAccountId);
                operationAmount.text = root.amountForInput(details.sourceAmount || row.amount);
            } else {
                editingSourceAccountId = row.accountId;
                editingTargetAccountId = "";
                operationType.currentIndex = row.type === "income" ? 0 : 1;
                operationAccount.currentIndex = root.indexByRole(financeController.accounts, "id", row.accountId);
                operationCategory.currentIndex = root.indexByRole(operationCategory.model, "value", row.categoryId);
                operationAmount.text = root.amountForInput(row.amount);
            }
            operationDescription.text = row.rawDescription || "";
            open();
        }

        onClosed: {
            editingId = "";
            editingTransaction = null;
            editingSourceAccountId = "";
            editingTargetAccountId = "";
        }

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }
        contentItem: ScrollView {
            id: operationDialogScroll
            clip: true
            contentWidth: availableWidth
            contentHeight: operationDialogForm.implicitHeight
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }

            ColumnLayout {
                id: operationDialogForm
                width: operationDialogScroll.availableWidth
                spacing: 16
                EditorialDialogTitle {
                    text: operationDialog.editingId ? qsTr("Редактирование операции") : qsTr("Новая операция")
                    color: root.accent
                }
                AppComboBox {
                    id: operationType
                    Layout.fillWidth: true
                    model: [qsTr("Доход"), qsTr("Расход"), qsTr("Перевод")]
                    onActivated: {
                        operationCategory.currentIndex = 0;
                        if (!operationDialog.editingTransaction)
                            return;

                        if (currentIndex === 2) {
                            operationDialog.selectTransferAccounts(operationDialog.editingSourceAccountId, operationDialog.editingTargetAccountId);
                        } else {
                            operationAccount.currentIndex = root.indexByRole(financeController.accounts, "id", operationDialog.editingTransaction.accountId);
                        }
                    }
                }
                MobileText {
                    font.family: MobileTheme.sans
                    visible: operationType.currentIndex === 2
                    text: qsTr("Откуда")
                    color: root.muted
                    font.pixelSize: 16
                }
                AppComboBox {
                    id: operationAccount
                    Layout.fillWidth: true
                    model: operationType.currentIndex === 2 ? financeController.allAccounts : financeController.accounts
                    textRole: operationType.currentIndex === 2 ? "displayName" : "name"
                    enabled: count > 0
                    emptyText: qsTr("Добавьте счёт")
                }
                MobileText {
                    font.family: MobileTheme.sans
                    visible: operationType.currentIndex === 2
                    text: qsTr("Куда")
                    color: root.muted
                    font.pixelSize: 16
                }
                AppComboBox {
                    id: transferTargetAccount
                    Layout.fillWidth: true
                    visible: operationType.currentIndex === 2
                    model: financeController.allAccounts
                    textRole: "displayName"
                    enabled: count > 0
                    emptyText: qsTr("Добавьте счёт")
                }
                AppComboBox {
                    id: operationCategory
                    Layout.fillWidth: true
                    visible: operationType.currentIndex !== 2
                    model: {
                        const selectedType = operationType.currentIndex === 0 ? "income" : "expense";
                        const result = financeController.categories.filter(function (category) {
                            return category.type === selectedType;
                        });
                        const editing = operationDialog.editingTransaction;
                        if (editing && editing.type === selectedType) {
                            let found = false;
                            for (let i = 0; i < result.length; ++i)
                                found = found || result[i].value === editing.categoryId;
                            if (!found)
                                result.push({
                                    label: editing.categoryName,
                                    value: editing.categoryId,
                                    type: editing.type
                                });
                        }
                        return result;
                    }
                    textRole: "label"
                    enabled: count > 0
                    emptyText: qsTr("Добавьте категорию")
                }
                AppTextField {
                    id: operationAmount
                    Layout.fillWidth: true
                    placeholderText: qsTr("Сумма")
                    validator: DoubleValidator {
                        bottom: 0.01
                        top: 999999999
                        decimals: 2
                    }
                }
                AppTextField {
                    id: operationDescription
                    Layout.fillWidth: true
                    placeholderText: qsTr("Описание")
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileText {
                        font.family: MobileTheme.sans
                        text: qsTr("Дата операции")
                        color: root.muted
                        font.pixelSize: 16
                    }

                    Button {
                        id: operationDateButton
                        Layout.fillWidth: true
                        implicitHeight: 44
                        hoverEnabled: true
                        text: Qt.formatDate(operationDialog.selectedDate, "dd.MM.yyyy")
                        onClicked: operationDateDialog.openFor(operationDialog.selectedDate)

                        contentItem: RowLayout {
                            spacing: 12
                            MobileText {
                                font.family: MobileTheme.sans
                                Layout.fillWidth: true
                                text: operationDateButton.text
                                color: root.accent
                                font.pixelSize: 16
                                verticalAlignment: Text.AlignVCenter
                            }
                            MobileText {
                                font.family: MobileTheme.sans
                                text: "▦"
                                color: root.navSelected
                                font.pixelSize: 18
                            }
                        }

                        background: Rectangle {
                            HardShadow {}

                            radius: 0
                            color: operationDateButton.down ? root.panel : operationDateButton.hovered ? root.controlHovered : root.soft
                            border.width: 1
                            border.color: operationDateButton.activeFocus ? root.navSelected : root.line
                        }
                    }
                }
                MobileText {
                    id: operationError
                    font.family: MobileTheme.sans
                    color: root.red
                    font.pixelSize: 16
                }
                RowLayout {
                    Item {
                        Layout.fillWidth: true
                    }
                    SoftButton {
                        text: qsTr("Отмена")
                        onClicked: operationDialog.close()
                    }
                    SoftButton {
                        text: qsTr("Сохранить")
                        highlighted: true
                        onClicked: {
                            if (!financeController.allAccounts.length) {
                                operationError.text = qsTr("Сначала добавьте счёт");
                                return;
                            }
                            const isTransfer = operationType.currentIndex === 2;
                            if (!operationAccount.model.length || operationAccount.currentIndex < 0) {
                                operationError.text = qsTr("Для выбранной операции нет доступного счёта");
                                return;
                            }
                            if (isTransfer && financeController.allAccounts.length < 2) {
                                operationError.text = qsTr("Для перевода нужны два счёта");
                                return;
                            }
                            if (isTransfer && transferTargetAccount.currentIndex < 0) {
                                operationError.text = qsTr("Выберите счёт назначения");
                                return;
                            }
                            if (!isTransfer && !operationCategory.model.length) {
                                operationError.text = qsTr("Сначала добавьте категорию");
                                return;
                            }
                            const account = operationAccount.model[operationAccount.currentIndex];
                            const category = isTransfer ? null : operationCategory.model[operationCategory.currentIndex];
                            const minor = Math.round((Number(operationAmount.text.replace(",", ".")) || 0) * 100);
                            const type = operationType.currentIndex === 0 ? "income" : operationType.currentIndex === 1 ? "expense" : "transfer";
                            const targetAccount = isTransfer ? transferTargetAccount.model[transferTargetAccount.currentIndex] : null;
                            const ok = operationDialog.editingId ? financeController.updateOperation(operationDialog.editingId, minor, operationDescription.text, isTransfer ? "" : category.value, account.id, type, isTransfer ? targetAccount.id : "", operationDialog.selectedDate) : isTransfer ? financeController.addTransfer(minor, operationDescription.text, account.id, targetAccount.id, operationDialog.selectedDate) : type === "income" ? financeController.addIncome(minor, operationDescription.text, category.value, account.currency, account.id, operationDialog.selectedDate) : financeController.addExpense(minor, operationDescription.text, category.value, account.currency, account.id, operationDialog.selectedDate);
                            if (ok)
                                operationDialog.close();
                            else
                                operationError.text = isTransfer ? qsTr("Проверьте сумму и выбранные счета") : qsTr("Проверьте сумму, счёт и категорию");
                        }
                    }
                }
            }
        }
    }

    EditorialDialog {
        id: dateFilterDialog
        width: Math.min(450, root.width - 20)
        height: Math.min(650, root.height - 24)
        modal: true
        anchors.centerIn: parent
        padding: root.width < 380 ? 14 : 18
        closePolicy: Popup.CloseOnEscape

        property var pendingFrom: null
        property var pendingTo: null
        property int displayedMonth: new Date().getMonth()
        property int displayedYear: new Date().getFullYear()

        function normalizedDate(date) {
            return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12, 0, 0, 0);
        }

        function openForCurrent() {
            const now = normalizedDate(new Date());
            pendingFrom = financeController.dateFilterActive ? root.dateFromIso(financeController.dateFilterFrom) : new Date(now.getFullYear(), now.getMonth(), 1, 12);
            pendingTo = financeController.dateFilterActive ? root.dateFromIso(financeController.dateFilterTo) : now;
            displayedMonth = pendingFrom.getMonth();
            displayedYear = pendingFrom.getFullYear();
            open();
        }

        function shiftMonth(offset) {
            const shifted = new Date(displayedYear, displayedMonth + offset, 1);
            displayedMonth = shifted.getMonth();
            displayedYear = shifted.getFullYear();
        }

        function isSameDay(left, right) {
            return left && right && left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate();
        }

        function isInsideRange(date) {
            if (!pendingFrom || !pendingTo)
                return false;
            const value = normalizedDate(date).getTime();
            return value >= pendingFrom.getTime() && value <= pendingTo.getTime();
        }

        function chooseDate(date) {
            const chosen = normalizedDate(date);
            if (!pendingFrom || pendingTo) {
                pendingFrom = chosen;
                pendingTo = null;
            } else if (chosen.getTime() < pendingFrom.getTime()) {
                pendingTo = pendingFrom;
                pendingFrom = chosen;
            } else {
                pendingTo = chosen;
            }
        }

        function applyRange(from, to) {
            financeController.setDateFilter(normalizedDate(from), normalizedDate(to));
            close();
        }

        function applyCurrentSelection() {
            if (!pendingFrom)
                return;
            applyRange(pendingFrom, pendingTo || pendingFrom);
        }

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }

        contentItem: EditorialDialogForm {
            spacing: 16

            EditorialDialogTitle {
                text: qsTr("Период")
                color: root.accent
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                SoftButton {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("Этот месяц")
                    onClicked: {
                        const to = dateFilterDialog.normalizedDate(new Date());
                        dateFilterDialog.applyRange(new Date(to.getFullYear(), to.getMonth(), 1, 12), to);
                    }
                }
                SoftButton {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("Этот год")
                    onClicked: {
                        const to = dateFilterDialog.normalizedDate(new Date());
                        dateFilterDialog.applyRange(new Date(to.getFullYear(), 0, 1, 12), to);
                    }
                }
                SoftButton {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("Все время")
                    onClicked: {
                        financeController.clearDateFilter();
                        dateFilterDialog.close();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                SoftButton {
                    Layout.preferredWidth: 44
                    text: "‹"
                    onClicked: dateFilterDialog.shiftMonth(-1)
                }

                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: root.calendarLabel(dateFilterDialog.displayedYear, dateFilterDialog.displayedMonth)
                    color: root.accent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

                SoftButton {
                    Layout.preferredWidth: 44
                    text: "›"
                    onClicked: dateFilterDialog.shiftMonth(1)
                }
            }

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: root.uiLocale()

                delegate: MobileText {
                    font.family: MobileTheme.sans
                    required property string shortName
                    text: shortName
                    color: root.muted
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MonthGrid {
                id: dateFilterCalendar

                Layout.fillWidth: true
                Layout.preferredHeight: 258
                month: dateFilterDialog.displayedMonth
                year: dateFilterDialog.displayedYear
                locale: root.uiLocale()

                delegate: Button {
                    id: filterDayButton
                    required property var model
                    flat: true
                    hoverEnabled: true
                    opacity: model.month === dateFilterCalendar.month ? 1 : 0.42
                    onClicked: dateFilterDialog.chooseDate(model.date)

                    readonly property bool rangeEdge: dateFilterDialog.isSameDay(model.date, dateFilterDialog.pendingFrom) || dateFilterDialog.isSameDay(model.date, dateFilterDialog.pendingTo)

                    contentItem: MobileText {
                        font.family: MobileTheme.sans
                        text: filterDayButton.model.day
                        color: filterDayButton.rangeEdge ? root.white : root.accent
                        font.pixelSize: 16
                        font.weight: filterDayButton.model.today ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 0
                        color: filterDayButton.rangeEdge ? root.accent : dateFilterDialog.isInsideRange(filterDayButton.model.date) ? root.pale : filterDayButton.hovered ? root.controlHovered : root.transparentColor
                    }
                }
            }

            MobileText {
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                text: !dateFilterDialog.pendingFrom ? qsTr("Выберите начало периода") : !dateFilterDialog.pendingTo ? qsTr("Теперь выберите конец периода") : Qt.formatDate(dateFilterDialog.pendingFrom, "dd.MM.yyyy") + " — " + Qt.formatDate(dateFilterDialog.pendingTo, "dd.MM.yyyy")
                color: root.muted
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }
                SoftButton {
                    text: qsTr("Отмена")
                    onClicked: dateFilterDialog.close()
                }
                SoftButton {
                    text: qsTr("Применить")
                    highlighted: true
                    enabled: dateFilterDialog.pendingFrom !== null
                    onClicked: dateFilterDialog.applyCurrentSelection()
                }
            }
        }
    }

    EditorialDialog {
        id: operationDateDialog
        width: Math.min(400, root.width - 20)
        height: Math.min(540, root.height - 24)
        modal: true
        anchors.centerIn: parent
        padding: root.width < 380 ? 14 : 18
        closePolicy: Popup.CloseOnEscape
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

        function isSameDay(left, right) {
            return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate();
        }

        function chooseDate(date) {
            operationDialog.selectDate(date);
            close();
        }

        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }

        contentItem: EditorialDialogForm {
            spacing: 16

            EditorialDialogTitle {
                text: qsTr("Дата операции")
                color: root.accent
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                SoftButton {
                    Layout.preferredWidth: 44
                    text: "‹"
                    onClicked: operationDateDialog.shiftMonth(-1)
                }

                MobileText {
                    font.family: MobileTheme.sans
                    Layout.fillWidth: true
                    text: root.calendarLabel(operationDateDialog.displayedYear, operationDateDialog.displayedMonth)
                    color: root.accent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

                SoftButton {
                    Layout.preferredWidth: 44
                    text: "›"
                    onClicked: operationDateDialog.shiftMonth(1)
                }
            }

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: root.uiLocale()

                delegate: MobileText {
                    font.family: MobileTheme.sans
                    required property string shortName
                    text: shortName
                    color: root.muted
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MonthGrid {
                id: operationCalendar

                Layout.fillWidth: true
                Layout.preferredHeight: 258
                month: operationDateDialog.displayedMonth
                year: operationDateDialog.displayedYear
                locale: root.uiLocale()

                delegate: Button {
                    id: dayButton
                    required property var model
                    flat: true
                    hoverEnabled: true
                    opacity: model.month === operationCalendar.month ? 1 : 0.42
                    onClicked: operationDateDialog.chooseDate(model.date)

                    contentItem: MobileText {
                        font.family: MobileTheme.sans
                        text: dayButton.model.day
                        color: operationDateDialog.isSameDay(dayButton.model.date, operationDialog.selectedDate) ? root.white : root.accent
                        font.pixelSize: 16
                        font.weight: dayButton.model.today ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 0
                        color: operationDateDialog.isSameDay(dayButton.model.date, operationDialog.selectedDate) ? root.accent : dayButton.hovered ? root.controlHovered : dayButton.model.today ? root.pale : root.transparentColor
                        border.width: dayButton.model.today && !operationDateDialog.isSameDay(dayButton.model.date, operationDialog.selectedDate) ? 1 : 0
                        border.color: root.accentSoft
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item {
                    Layout.fillWidth: true
                }
                SoftButton {
                    text: qsTr("Сегодня")
                    onClicked: operationDateDialog.chooseDate(new Date())
                }
                SoftButton {
                    text: qsTr("Отмена")
                    onClicked: operationDateDialog.close()
                }
            }
        }
    }

    EditorialDialog {
        id: categoryDialog
        width: Math.min(560, root.width - 20)
        modal: true
        anchors.centerIn: parent
        padding: root.width < 380 ? 14 : 18
        property var editingData: null
        property bool confirmingDelete: false
        readonly property string editingId: editingData ? editingData.value : ""

        function openForManagement() {
            editingData = null;
            confirmingDelete = false;
            categoryNameField.clear();
            categoryType.currentIndex = 0;
            categoryType.enabled = true;
            categoryError.text = "";
            open();
        }

        function openForEdit(row) {
            editingData = row;
            confirmingDelete = false;
            categoryNameField.text = row.label || "";
            categoryType.currentIndex = row.type === "expense" ? 1 : 0;
            categoryType.enabled = false;
            categoryError.text = "";
            open();
        }
        background: Rectangle {
            HardShadow {}

            color: root.panel
            radius: 0
            border.width: 1
            border.color: root.line
        }
        contentItem: EditorialDialogForm {
            spacing: 12
            EditorialDialogTitle {
                text: qsTr("Категории")
                color: root.accent
            }
            ColumnLayout {
                Layout.fillWidth: true
                AppTextField {
                    id: categoryNameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Название категории")
                }
                AppComboBox {
                    id: categoryType
                    Layout.fillWidth: true
                    model: [qsTr("Доход"), qsTr("Расход")]
                }
                SoftButton {
                    Layout.fillWidth: true
                    text: qsTr("Сохранить")
                    highlighted: true
                    onClicked: {
                        const ok = categoryDialog.editingId.length > 0 ? financeController.renameCategory(categoryDialog.editingId, categoryNameField.text) : financeController.addCategory(categoryNameField.text, categoryType.currentIndex === 0 ? "income" : "expense");
                        if (!ok) {
                            categoryError.text = qsTr("Не удалось сохранить категорию");
                        } else if (categoryDialog.editingId.length > 0) {
                            categoryDialog.close();
                        } else {
                            categoryNameField.clear();
                            categoryError.text = "";
                        }
                    }
                }
                SoftButton {
                    Layout.fillWidth: true
                    visible: categoryDialog.editingId.length > 0
                    text: categoryDialog.confirmingDelete ? qsTr("Нажмите ещё раз, чтобы удалить") : qsTr("Удалить категорию")
                    onClicked: {
                        if (!categoryDialog.confirmingDelete) {
                            categoryDialog.confirmingDelete = true;
                            return;
                        }
                        if (financeController.deleteCategory(categoryDialog.editingId))
                            categoryDialog.close();
                        else
                            categoryError.text = qsTr("Не удалось удалить категорию");
                    }
                }
            }
            MobileText {
                id: categoryError
                font.family: MobileTheme.sans
                color: root.red
                font.pixelSize: 16
            }
            RowLayout {
                Item {
                    Layout.fillWidth: true
                }
                SoftButton {
                    text: qsTr("Закрыть")
                    onClicked: categoryDialog.close()
                }
            }
        }
    }
}
