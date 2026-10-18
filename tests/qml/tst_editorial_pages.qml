import QtQuick
import QtQuick.Controls
import QtTest
import "../../ui/computer/common"
import "../../ui/computer/categories"
import "../../ui/computer/goals"
import "../../ui/computer/notes"
import "../../ui/computer/trajectory"
import "../../ui/computer/analytics"
import "../../ui/computer/settings"

Item {
    id: scene
    width: 1920
    height: 1080
    property string current: "categories"
    property string page: current
    property string csvStatus: ""
    property bool csvStatusOk: true
    property var activeHistorySelection: null
    property var scrollController: null
    property color accent: "#031528"
    property color muted: "#59616a"
    property color panel: "#f3eddf"
    property color soft: "#f3eddf"
    property color line: "#bbb5a8"
    property color white: "#f3eddf"
    property color income: "#2e5947"
    property color red: "#b84932"
    property color controlHovered: "#ece5d7"
    property int saves: 0
    property int actions: 0
    function money(v, currency, sign) {
        return (sign && v > 0 ? "+" : "") + Number(v / 100).toLocaleString(Qt.locale("ru_RU"), "f", 0) + " " + ({
                                                                                                                    RUB: "₽",
                                                                                                                    USD: "$",
                                                                                                                    EUR: "€",
                                                                                                                    CNY: "¥"
                                                                                                                }[currency]
                                                                                                                || currency);
    }
    function capitalAxisMoney(v, currency) {
        return Math.round(v / 100000) + " тыс.";
    }
    function dateFilterLabel() {
        return "Всё время";
    }
    function selectedBudget() {
        return finance.budgets[0];
    }
    function selectedProject() {
        return finance.projects[0];
    }
    function budgetMonthLabel() {
        return "октябрь 2026";
    }
    function shiftBudgetMonth(n) {
        ++actions;
    }
    function transactionSummary(row) {
        return row.description || "Операция";
    }
    function expenseRowsForYear(year) {
        return Array.from({
                              length: 12
                          }, function (_, i) {
                              return {
                                  monthIndex: i,
                                  totalMinor: 1000000 + i * 10000
                              };
                          });
    }
    function averageCompletedMonthExpense(rows) {
        return 1000000;
    }
    function expenseMonthLabel(i) {
        return ["ЯНВ", "ФЕВ", "МАР", "АПР", "МАЙ", "ИЮН", "ИЮЛ", "АВГ", "СЕН", "ОКТ", "НОЯ", "ДЕК"][i];
    }
    function expenseHistoryFirstYear() {
        return 2020;
    }
    function expenseHistoryLastYear() {
        return 2026;
    }
    function editorialManageCategories() {
        ++actions;
    }
    function editorialCategoryHistory(row) {
        ++actions;
    }
    function editorialNewLedger(budget) {
        ++actions;
    }
    function editorialProjectOperation() {
        ++actions;
    }
    function openCategoryContextMenu(row, source, x, y) {
        ++actions;
    }
    function openBudgetContextMenu(row, source, x, y) {
        ++actions;
    }
    function openProjectContextMenu(row, source, x, y) {
        ++actions;
    }
    function openTransactionContextMenu(row, source, x, y) {
        ++actions;
    }
    function editorialDeleteHistory(selection) {
        ++actions;
    }
    QtObject {
        id: appAccess
        property bool enabled: false
        property bool storeAvailable: false
        property bool storeChecked: true
        property bool ready: true
        property bool busy: false
        property string storeError: "Системное хранилище недоступно"
        property string error: ""
    }
    QtObject {
        id: databaseProtection
        property bool encrypted: false
        property bool supported: false
        property bool ready: true
        property bool busy: false
    }
    QtObject {
        id: finance
        property string appCurrency: "RUB"
        property string analyticsCurrency: "USD"
        property string uiLanguage: "ru"
        property var currentCurrencyRates: [
            {
                code: "RUB",
                rate: 1
            },
            {
                code: "USD",
                rate: 95
            },
            {
                code: "EUR",
                rate: 104
            },
            {
                code: "CNY",
                rate: 13.3
            }
        ]
        property var categories: [
            {
                value: "work",
                label: "Работа",
                type: "income"
            },
            {
                value: "food",
                label: "Продукты",
                type: "expense"
            }
        ]
        property var allAccounts: [
            {
                id: "broker",
                name: "Брокерский счёт"
            },
            {
                id: "deposit",
                name: "Вклад | Сбережения"
            }
        ]
        property var investmentPositions: [
            {
                id: "pos1",
                accountId: "broker"
            }
        ]
        property var financialGoals: [
            {
                id: "g1",
                name: "Подушка безопасности",
                currentMinor: 6000000,
                targetMinor: 30000000,
                remainingMinor: 24000000,
                currency: "RUB",
                ratio: .2,
                complete: true,
                achieved: false,
                overdue: false,
                deadline: "",
                allSources: false,
                sourceIds: ["account:deposit"]
            }
        ]
        property var goalSources: [
            {
                id: "account:deposit",
                name: "Вклад | Сбережения"
            }
        ]
        property var financialTrajectory: ({
                                               currency: appCurrency,
                                               currentMinor: 26545617,
                                               averageSavingMinor: 1800000,
                                               savingRate: 21.2,
                                               complete: true,
                                               analysisMonths: 6,
                                               horizonMonths: 36,
                                               annualReturnPercent: 5,
                                               annualInflationPercent: 6,
                                               incomeChangePercent: 0,
                                               expenseChangePercent: 0,
                                               purchaseMinor: 0,
                                               purchaseMonth: 0,
                                               history: [],
                                               forecast: [
                                                   {
                                                       date: "2026-10-18",
                                                       valueMinor: 26545617,
                                                       realMinor: 26545617
                                                   },
                                                   {
                                                       date: "2027-10-18",
                                                       valueMinor: 50000000,
                                                       realMinor: 47000000
                                                   },
                                                   {
                                                       date: "2029-10-18",
                                                       valueMinor: 94700000,
                                                       realMinor: 79000000
                                                   }
                                               ]
                                           })
        property string notesText: "Финансовые заметки\n\n— Откладывать часть дохода.\n— Проверить подписки."
        property bool notesAvailable: true
        property string notesError: ""
        signal notesChanged
        function setNotesText(text) {
            notesText = text;
            notesChanged();
        }
        function saveNotes() {
            ++scene.saves;
        }
        function refreshInvestmentQuotes() {
        }
        function saveFinancialTrajectorySettings(value) {
            trajectorySettings = value;
            return {
                ok: true
            };
        }
        property var trajectorySettings: ({})
        property var budgets: [
            {
                id: "b1",
                name: "Повседневные расходы",
                displayLimitMinor: 4500000,
                displaySpentMinor: 1200000,
                displayCurrency: appCurrency,
                currency: "RUB",
                progress: .26,
                allAccounts: true,
                categoryLimits: [
                    {
                        name: "Продукты",
                        spentMinor: 1200000,
                        limitMinor: 2000000,
                        progress: .6
                    }
                ]
            }
        ]
        property var projects: [
            {
                id: "p1",
                name: "Работа и развитие",
                operationCount: 200,
                incomeMinor: 8000000,
                expenseMinor: 2000000,
                resultMinor: 6000000
            }
        ]
        property string selectedBudgetId: "b1"
        property string selectedProjectId: "p1"
        property var projectTransactions: Array.from({
                                                         length: 200
                                                     }, function (_, i) {
                                                         return {
                                                             id: "op" + i,
                                                             date: new Date(2026, 9, 18),
                                                             description: "Операция проекта",
                                                             categoryName: "Работа",
                                                             displayAmount: 100000,
                                                             amount: 100000
                                                         };
                                                     })
        property var budgetTransactions: projectTransactions.slice(0, 5).map(function (r) {
            return Object.assign({}, r, {
                                     budgetAmountMinor: 120000,
                                     budgetCurrency: "RUB"
                                 });
        })
        property string performanceAccountId: ""
        property string performanceInflation: "6"
        property var performanceAccounts: [
            {
                id: "broker",
                name: "Брокерский счёт"
            },
            {
                id: "deposit",
                name: "Вклад | Сбережения"
            }
        ]
        property var performanceDeposit: ({
                                              rate: "15.0000",
                                              capitalization: "monthly"
                                          })
        property var investmentPerformance: ({
                                                 currency: appCurrency,
                                                 from: "2026-07-18",
                                                 to: "2026-10-18",
                                                 observationCount: 90,
                                                 gainMinor: 1260000,
                                                 periodPercent: 6.28,
                                                 annualPercent: 14.8,
                                                 realizedMinor: 420000,
                                                 unrealizedMinor: 840000,
                                                 realPercent: 4.74,
                                                 breakdown: [
                                                     {
                                                         label: "Прибыль после продаж",
                                                         amountMinor: 420000
                                                     },
                                                     {
                                                         label: "Изменение открытой прибыли",
                                                         amountMinor: 690000
                                                     },
                                                     {
                                                         label: "Валютная переоценка",
                                                         amountMinor: 150000
                                                     }
                                                 ],
                                                 dataQuality: {
                                                     checkedRows: 180,
                                                     errors: 1,
                                                     warnings: 0,
                                                     notes: 0,
                                                     items: [
                                                         {
                                                             severity: "error",
                                                             label: "Нет котировки",
                                                             account: "Брокерский счёт",
                                                             asset: "ОФЗ",
                                                             dateFrom: "2026-10-10",
                                                             impact: "Неполный расчёт",
                                                             action: "Обновите котировку"
                                                         }
                                                     ]
                                                 },
                                                 depositComparison: {
                                                     available: true,
                                                     portfolioGainMinor: 1260000,
                                                     depositGainMinor: 1000000,
                                                     differenceMinor: 260000,
                                                     series: [
                                                         {
                                                             date: "2026-07-18",
                                                             portfolioMinor: 20000000,
                                                             depositMinor: 20000000
                                                         },
                                                         {
                                                             date: "2026-10-18",
                                                             portfolioMinor: 21260000,
                                                             depositMinor: 21000000
                                                         }
                                                     ]
                                                 },
                                                 risk: {
                                                     available: true,
                                                     annualVolatilityPercent: 6,
                                                     maximumDrawdownPercent: -2,
                                                     currentDrawdownPercent: -.5,
                                                     bestDayPercent: 1,
                                                     worstDayPercent: -1,
                                                     returnDays: 90,
                                                     drawdowns: [
                                                         {
                                                             date: "2026-07-18",
                                                             percent: 0
                                                         },
                                                         {
                                                             date: "2026-08-18",
                                                             percent: -2
                                                         },
                                                         {
                                                             date: "2026-10-18",
                                                             percent: -.5
                                                         }
                                                     ]
                                                 },
                                                 allocation: {
                                                     pieAvailable: true,
                                                     items: [
                                                         {
                                                             label: "ОФЗ",
                                                             amountMinor: 10000000,
                                                             percent: 60
                                                         },
                                                         {
                                                             label: "Вклад",
                                                             amountMinor: 7000000,
                                                             percent: 40
                                                         }
                                                     ],
                                                     types: [
                                                         {
                                                             label: "Облигации",
                                                             amountMinor: 10000000,
                                                             percent: 60
                                                         },
                                                         {
                                                             label: "Вклады",
                                                             amountMinor: 7000000,
                                                             percent: 40
                                                         }
                                                     ],
                                                     accounts: [
                                                         {
                                                             label: "Брокерский счёт",
                                                             amountMinor: 10000000,
                                                             percent: 60
                                                         },
                                                         {
                                                             label: "Вклад",
                                                             amountMinor: 7000000,
                                                             percent: 40
                                                         }
                                                     ],
                                                     currencies: [
                                                         {
                                                             label: "RUB",
                                                             amountMinor: 17000000,
                                                             percent: 100
                                                         }
                                                     ]
                                                 },
                                                 contributions: {
                                                     items: [
                                                         {
                                                             label: "ОФЗ",
                                                             amountMinor: 900000
                                                         },
                                                         {
                                                             label: "Вклад",
                                                             amountMinor: 360000
                                                         }
                                                     ],
                                                     fxMinor: 0,
                                                     unexplainedMinor: 0
                                                 },
                                                 payments: {
                                                     count: 2,
                                                     netMinor: 300000,
                                                     grossMinor: null,
                                                     feesMinor: null,
                                                     taxMinor: null,
                                                     months: [
                                                         {
                                                             label: "09.2026",
                                                             netMinor: 100000
                                                         },
                                                         {
                                                             label: "10.2026",
                                                             netMinor: 200000
                                                         }
                                                     ],
                                                     kinds: [
                                                         {
                                                             label: "Купоны",
                                                             netMinor: 300000
                                                         }
                                                     ],
                                                     events: []
                                                 }
                                             })
        property var averageReturnItems: [
            {
                id: "position:pos1",
                title: "ОФЗ 26238",
                group: "investments",
                valueMinor: 6000000,
                annualPercent: 14.8
            },
            {
                id: "deposit:deposit",
                title: "Вклад | Сбережения",
                group: "investments",
                valueMinor: 7300063,
                annualPercent: 15.2
            },
            {
                id: "crypto:bybit:SOL",
                title: "Bybit · SOL",
                group: "crypto",
                valueMinor: 1650000,
                annualPercent: 11.2
            }
        ]
        property var excluded: []
        property bool merged: true
        property var averageReturnSummary: {
            const groups = merged ? [
                                        {
                                            key: "all",
                                            title: "Инвестиции и криптовалюта"
                                        }
                                    ] : [
                                        {
                                            key: "investments",
                                            title: "Инвестиции"
                                        },
                                        {
                                            key: "crypto",
                                            title: "Криптовалюта"
                                        }
                                    ];
            return {
                merged: merged,
                excluded: excluded,
                groups: groups.map(function (g) {
                    const items = finance.averageReturnItems.filter(function (i) {
                        return (g.key === "all" || i.group === g.key) && finance.excluded.indexOf(i.id) < 0;
                    }), sum = items.reduce(function (s, i) {
                        return s + i.valueMinor;
                    }, 0);
                    return {
                        key: g.key,
                        title: g.title,
                        annualPercent: sum ? items.reduce(function (s, i) {
                            return s + i.valueMinor * i.annualPercent;
                        }, 0) / sum : null,
                        valueMinor: sum,
                        counted: items.length,
                        shown: items.length,
                        slices: items.map(function (i) {
                            return {
                                id: i.id,
                                title: i.title,
                                share: i.valueMinor / sum
                            };
                        })
                    };
                })
            };
        }
        function setAverageReturnSelection(ids, value) {
            excluded = ids;
            merged = value;
        }
        function setPerformanceAccount(value) {
            performanceAccountId = value;
        }
        function setPerformanceInflation(value) {
            performanceInflation = value;
            return true;
        }
        function setPerformanceDeposit(value, mode) {
            performanceDeposit = {
                rate: value,
                capitalization: mode
            };
            return true;
        }
        property var benchmarkIndices: [
            {
                key: "MCFTR",
                name: "Индекс полной доходности"
            }
        ]
        property var benchmarkSelection: ({
                                              key: "MCFTR",
                                              symbol: "MCFTR",
                                              kind: "index"
                                          })
        property var benchmarkComparison: ({
                                               available: true,
                                               canRefresh: true,
                                               portfolioPercent: 6.28,
                                               benchmarkPercent: 5.1,
                                               differencePoints: 1.18,
                                               points: [
                                                   {
                                                       date: "2026-07-18",
                                                       portfolio: 0,
                                                       benchmark: 0
                                                   },
                                                   {
                                                       date: "2026-10-18",
                                                       portfolio: 6.28,
                                                       benchmark: 5.1
                                                   }
                                               ]
                                           })
        property bool benchmarkBusy: false
        property string benchmarkError: ""
        property bool benchmarkSearchBusy: false
        property string benchmarkSearchError: ""
        property var benchmarkSearchResults: []
        function selectBenchmarkIndex(key) {
            benchmarkSelection = {
                key: key,
                kind: "index"
            };
        }
        function refreshBenchmark() {
            ++scene.actions;
        }
        function searchBenchmarkFunds(q) {
            ++scene.actions;
        }
        function selectBenchmarkFund(i) {
            ++scene.actions;
        }
        property var capitalHistoryRub: [
            {
                date: "2026-07-18",
                totalMinor: 18000000
            },
            {
                date: "2026-10-18",
                totalMinor: 26545617
            }
        ]
        property var capitalHistoryAnalyticsCurrency: capitalHistoryRub
        property bool automaticCurrencyRates: true
        property real manualRubToRubRate: 1
        property real manualUsdToRubRate: 95
        property real manualEurToRubRate: 104
        property real manualCnyToRubRate: 13.3
    }
    Loader {
        id: loader
        x: scene.width <= 850 ? 72 : scene.width <= 1150 ? 184 : scene.width <= 1500 ? 208 : 240
        width: scene.width - x
        height: scene.height
        sourceComponent: scene.current === "goals" ? goals : scene.current === "trajectory" ? trajectory : scene.current
                                                                                              === "notes" ? notes :
                                                                                                            scene.current
                                                                                                            === "analytics"
                                                                                                            ? analytics :
                                                                                                              scene.current
                                                                                                              === "budgets"
                                                                                                              ? budgets :
                                                                                                                scene.current
                                                                                                                === "projects"
                                                                                                                ? projects :
                                                                                                                  scene.current
                                                                                                                  === "settings"
                                                                                                                  ? settings :
                                                                                                                    categories
    }
    Component {
        id: categories
        EditorialCategoriesPage {
            host: scene
            controller: finance
        }
    }
    Component {
        id: goals
        FinancialGoalsPage {
            theme: scene
            controller: finance
        }
    }
    Component {
        id: trajectory
        FinancialTrajectoryPage {
            theme: scene
            controller: finance
        }
    }
    Component {
        id: notes
        EditorialNotesPage {
            host: scene
            controller: finance
        }
    }
    Component {
        id: analytics
        EditorialAnalyticsPage {
            host: scene
            controller: finance
        }
    }
    Component {
        id: budgets
        EditorialLedgerPage {
            host: scene
            controller: finance
            budget: true
        }
    }
    Component {
        id: projects
        EditorialLedgerPage {
            host: scene
            controller: finance
            budget: false
        }
    }
    Component {
        id: settings
        EditorialSettingsPage {
            host: scene
            controller: finance
        }
    }
    TestCase {
        name: "EditorialPages"
        when: windowShown
        function open(page) {
            scene.current = page;
            tryVerify(function () {
                return loader.status === Loader.Ready && loader.item !== null;
            });
            wait(40);
            return loader.item;
        }
        function init() {
            scene.width = 1920;
            scene.height = 1080;
            finance.excluded = [];
            finance.merged = true;
        }
        function test_shared_headers_and_sizes() {
            const pages = ["categories", "goals", "notes", "trajectory", "budgets", "projects", "analytics",
                           "settings"];


            for (let s = 0; s < 3; s++) {
                scene.width = [1920, 1366, 1024][s];
                scene.height = [1080, 900, 768][s];
                for (let i = 0; i < pages.length; i++) {
                    const p = open(pages[i]);
                    compare(p.masthead.height, s === 0 ? 128 : 104);
                    compare(p.masthead.y, 0);
                    const title = findChild(p, "editorialPageTitle");
                    compare(title.font.pixelSize, s === 0 ? 80 : s === 1 ? 72 : Math.round(Math.min(56, Math.max(40,
                                                                                                                 scene.width
                                                                                                                 * .048))));
                    const rule = findChild(p, "editorialHeadingRule");
                    compare(rule.y, p.masthead.height);
                    verify(findChild(p, "editorialCurrency") !== null);
                    compare(p.period, pages[i] === "analytics");
                    if (typeof uiCaptureDirectory !== "undefined" && uiCaptureDirectory !== "" && s === 0) {
                        wait(60);
                        grabImage(loader).save(uiCaptureDirectory + "/" + pages[i] + ".png");
                        if (pages[i] === "analytics") {
                            const names = ["editorialQualitySection", "editorialStructureSection"];
                            for (let n = 0; n < names.length; n++) {
                                const section = findChild(p, names[n]);
                                p.contentY = section.mapToItem(p.contentItem, 0, 0).y - 24;
                                wait(40);
                                grabImage(loader).save(uiCaptureDirectory + "/" + names[n] + ".png");
                            }
                            finance.setAverageReturnSelection([], false);
                            p.contentY = findChild(p, "editorialReturnFigures").mapToItem(p.contentItem, 0, 0).y - 80;
                            wait(40);
                            grabImage(loader).save(uiCaptureDirectory + "/analytics-separate.png");
                            finance.setAverageReturnSelection([], true);
                        }
                    }
                }
            }
        }
        function test_notes_save_plain_text() {
            const p = open("notes"), editor = findChild(p, "editorialNotesEditor");
            editor.text = "Первая строка\nВторая строка";
            compare(finance.notesText, editor.text);
            verify(editor.textFormat === TextEdit.PlainText);
            wait(20);
            verify(editor.contentHeight >= 64, "Content height: " + editor.contentHeight);
            const before = editor.text;
            editor.insert(editor.length, "!");
            compare(editor.text, before + "!");
            editor.undo();
            compare(editor.text, before);
        }
        function test_annual_one_or_two_pies_and_selection() {
            const p = open("analytics");
            const figures = findChild(p, "editorialReturnFigures");
            compare(figures.columns, 1);
            finance.setAverageReturnSelection([], false);
            wait(30);
            compare(figures.columns, 2);
            finance.setAverageReturnSelection(["position:pos1"], false);
            wait(20);
            verify(finance.averageReturnSummary.groups[0].valueMinor < 13300063);
        }
        function test_metrics_align_both_rows() {
            const p = open("analytics"), grid = findChild(p, "editorialPerformanceMetrics");
            const cells = [];
            for (let i = 0; i < grid.children.length; i++) {
                const child = grid.children[i];
                if (child.objectName === "editorialMetricCell")
                    cells.push(child);
            }
            compare(cells.length, 6);
            compare(findChild(cells[0], "editorialMetricContent").x, findChild(cells[3], "editorialMetricContent").x);
            compare(cells[2].width, cells[5].width);
        }
        function test_project_rows_are_virtualized() {
            const p = open("projects");
            verify(p.contentHeight > p.height);
            const table = findChild(p, "editorialOperationsTable");
            verify(table !== null);
            verify(table.lastRow - table.firstRow < 30);
            p.contentY = p.contentHeight - p.height;
            wait(20);
            verify(table.firstRow > 150);
        }
        function test_trajectory_uses_real_settings() {
            const p = open("trajectory");
            p.scenario("safe");
            compare(finance.trajectorySettings.annualReturnPercent, 2);
            const chart = findChild(p, "editorialTrajectoryChart");
            compare(chart.series.length, 2);
            compare(chart.series[0].dashed, undefined);
            compare(chart.series[1].dashed, true);
        }
    }
}
