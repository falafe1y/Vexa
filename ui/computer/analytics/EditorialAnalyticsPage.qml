import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../dashboard"

EditorialPage {
    id: page
    title: "Аналитика."
    period: true
    property string inflationError: ""
    property int allocationIndex: 0
    property int expenseYear: new Date().getFullYear()
    readonly property var report: controller.investmentPerformance || ({})
    readonly property var quality: report.dataQuality || ({})
    readonly property var risk: report.risk || ({})
    readonly property var allocation: report.allocation || ({})
    readonly property var contributions: report.contributions || ({})
    readonly property var payments: report.payments || ({})
    readonly property var benchmark: controller.benchmarkComparison || ({})
    readonly property var benchmarkSelection: controller.benchmarkSelection || ({})
    readonly property var deposit: report.depositComparison || ({})
    readonly property var accountChoices: [
        {
            id: "",
            name: "Все инвестиционные счета"
        },
        {
            id: "group:brokerage",
            name: "Все брокерские счета"
        },
        {
            id: "group:deposit",
            name: "Все вклады"
        }
    ].concat(controller.performanceAccounts || [])
    readonly property var benchmarkChoices: [
        {
            key: "",
            name: "Без сравнения"
        }
    ].concat(controller.benchmarkIndices || []).concat([
                                                           {
                                                               key: "fund",
                                                               name: "Биржевой фонд Мосбиржи…"
                                                           }
                                                       ])
    readonly property var holdingRows: (page.allocationIndex === 1 ? allocation.types : page.allocationIndex === 2
                                                                     ? allocation.accounts : page.allocationIndex === 3
                                                                       ? allocation.currencies : allocation.items) || []
    readonly property var qualityRows: (quality.items || []).filter(function (row) {
        const level = ["", "error", "warning", "info"][severity.currentIndex];
        const needle = qualitySearch.text.trim().toLowerCase();
        return (!level || row.severity === level) && (!needle || [row.label, row.account, row.asset, row.impact, row.action,
                                                                  row.dateFrom, row.dateTo, (row.dates || []).join(
                                                                      " ")].join(" ").toLowerCase().indexOf(needle)
                                                      >= 0);
    })
    function available(v) {
        return v !== null && v !== undefined && isFinite(Number(v));
    }
    function amount(v, currency) {
        return available(v) ? host.money(v, currency || report.currency || controller.appCurrency, false) : "—";
    }
    function percent(v) {
        return available(v) ? Number(v).toLocaleString(Qt.locale("ru_RU"), "f", 2) + " %" : "—";
    }
    function tone(v) {
        return page.available(v) && Number(v) < 0 ? "#b84932" : "#2e5947";
    }
    function date(v) {
        return v ? Qt.formatDate(new Date(v), "dd.MM.yyyy") : "—";
    }
    function series(rows, key) {
        return (rows || []).map(function (r) {
            return {
                date: r.date,
                value: r[key]
            };
        });
    }
    function selectedIndex(rows, key, value) {
        for (let i = 0; i < rows.length; i++)
            if (rows[i][key] === value)
                return i;
        return 0;
    }
    function benchmarkIndex() {
        return benchmarkSelection.kind === "fund" ? benchmarkChoices.length - 1 : selectedIndex(benchmarkChoices, "key",
                                                                                                benchmarkSelection.key
                                                                                                || "");
    }
    component Note: EditorialText {
        width: parent.width
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        font.pixelSize: 14
        color: "#59616a"
        height: implicitHeight
    }
    component Rule: Rectangle {
        width: parent.width
        height: 1
        color: "#bbb5a8"
    }
    component ListRow: Item {
        property string label: ""
        property string value: ""
        property color tone: "#031528"
        width: parent.width
        height: 48
        EditorialText {
            height: parent.height
            width: Math.max(0, parent.width - result.width - 24)
            text: parent.label
            font.pixelSize: 14
        }
        EditorialText {
            id: result
            anchors.right: parent.right
            height: parent.height
            text: parent.value
            font.family: "Cousine"
            font.pixelSize: 14
            color: parent.tone
        }
        Rule {
            y: parent.height - 1
        }
    }
    Item {
        width: parent.width
        height: 80
        EditorialSection {
            width: Math.max(0, parent.width - account.width - 24)
            height: 80
            number: 1
            title: "Доходность"
        }
        EditorialChoice {
            id: account
            objectName: "editorialPerformanceAccount"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(320, parent.width * .45)
            model: page.accountChoices
            textRole: "name"
            currentIndex: page.selectedIndex(page.accountChoices, "id", page.controller.performanceAccountId)
            onActivated: page.controller.setPerformanceAccount(page.accountChoices[currentIndex].id)
        }
    }
    EditorialMetrics {
        objectName: "editorialPerformanceMetrics"
        width: parent.width
        height: implicitHeight
        columns: page.host.width <= 850 ? 2 : 3
        metrics: [
            {
                label: "Результат за период",
                value: page.amount(page.report.gainMinor),
                hint: "Без пополнений и выводов",
                color: page.tone(page.report.gainMinor)
            },
            {
                label: "Доходность за период",
                value: page.percent(page.report.periodPercent),
                hint: "С учётом денежных потоков"
            },
            {
                label: "Годовой эквивалент",
                value: page.percent(page.report.annualPercent),
                hint: "Пересчёт темпа роста на год"
            },
            {
                label: "Прибыль после продаж",
                value: page.amount(page.report.realizedMinor),
                hint: "После учтённых расходов",
                color: page.tone(page.report.realizedMinor)
            },
            {
                label: "Прибыль открытых позиций",
                value: page.amount(page.report.unrealizedMinor),
                hint: "Относительно стоимости приобретения",
                color: page.tone(page.report.unrealizedMinor)
            },
            {
                label: "После заданной инфляции",
                value: page.percent(page.report.realPercent),
                hint: "Годовая ставка: %1 %".arg(page.controller.performanceInflation || "—")
            }
        ]
    }
    EditorialReportSection {
        width: parent.width
        number: 2
        title: "Разложение результата"
        toolbar: RowLayout {
            spacing: 12
            EditorialText {
                text: "Инфляция, % в год"
                font.pixelSize: 14
            }
            EditorialField {
                id: inflation
                objectName: "editorialInflation"
                Layout.preferredWidth: 80
                text: page.controller.performanceInflation
                placeholderText: "—"
                onAccepted: apply.clicked()
            }
            EditorialAction {
                id: apply
                text: "ПРИМЕНИТЬ"
                arrow: false
                onClicked: page.inflationError = page.controller.setPerformanceInflation(inflation.text) ? "" : "Введите ставку больше −100 и не выше 1000 %, до четырёх знаков после запятой."
            }
        }
        Note {
            visible: !!page.inflationError
            text: page.inflationError
            color: "#b84932"
        }
        GridLayout {
            width: parent.width
            columns: page.host.width <= 1150 ? 2 : 3
            columnSpacing: 24
            rowSpacing: 24
            Repeater {
                model: page.report.breakdown || []
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    spacing: 8
                    EditorialText {
                        Layout.fillWidth: true
                        text: modelData.label
                        font.family: "Cousine"
                        font.pixelSize: 12
                        color: "#59616a"
                    }
                    EditorialText {
                        Layout.fillWidth: true
                        text: page.amount(modelData.amountMinor)
                        font.family: "PT Serif"
                        font.pixelSize: 28
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        color: "#031528"
                        opacity: page.available(modelData.amountMinor) ? 1 : .15
                    }
                }
            }
        }
        Note {
            visible: !page.available(page.report.gainMinor)
            text: "Разложение появится, когда будут известны результат периода и денежные потоки."
        }
        Note {
            text: "Оценки: %1 — %2 · Дней с оценкой: %3".arg(page.date(page.report.from)).arg(page.date(
                                                                                                        page.report.to)).arg(
                      page.report.observationCount || 0)
        }
        EditorialAction {
            text: "ПОЯСНЕНИЯ К РАСЧЁТУ"
            arrow: false
            onClicked: warnings.visible = !warnings.visible
        }
        Note {
            id: warnings
            visible: false
            text: (page.report.warnings || []).join("\n") || "Пополнения и выводы исключаются из результата. Годовой эквивалент показывает темп роста за период и не является прогнозом."
        }
    }
    EditorialAverageReturn {
        width: parent.width
        controller: page.controller
        host: page.host
    }
    EditorialReportSection {
        objectName: "editorialQualitySection"
        width: parent.width
        number: 4
        title: "Качество данных"
        EditorialMetrics {
            width: parent.width
            height: implicitHeight
            columns: 4
            metrics: [
                {
                    label: "Строк оценок",
                    value: String(page.quality.checkedRows || 0)
                },
                {
                    label: "Препятствуют расчёту",
                    value: String(page.quality.errors || 0)
                },
                {
                    label: "Ограничивают разбор",
                    value: String(page.quality.warnings || 0)
                },
                {
                    label: "Особенности учёта",
                    value: String(page.quality.notes || 0)
                }
            ]
        }
        EditorialCheck {
            id: qualityOpen
            text: "Показать проблемы (%1)".arg((page.quality.items || []).length)
        }
        Column {
            width: parent.width
            visible: qualityOpen.checked
            spacing: 16
            RowLayout {
                width: parent.width
                spacing: 24
                EditorialChoice {
                    id: severity
                    objectName: "editorialQualitySeverity"
                    Layout.preferredWidth: 280
                    model: ["Все проблемы", "Препятствуют расчёту", "Ограничивают разбор", "Особенности учёта"]
                }
                EditorialField {
                    id: qualitySearch
                    objectName: "editorialQualitySearch"
                    Layout.fillWidth: true
                    placeholderText: "Счёт, актив, проблема или дата"
                }
            }
            Repeater {
                model: page.qualityRows
                Column {
                    required property var modelData
                    width: parent.width
                    spacing: 8
                    EditorialText {
                        width: parent.width
                        text: modelData.label
                        font.bold: true
                    }
                    Note {
                        text: [modelData.account, modelData.asset, page.date(modelData.dateFrom)].filter(function (v) {
                            return !!v;
                        }).join(" · ")
                    }
                    Note {
                        text: modelData.impact
                    }
                    Note {
                        text: "Что проверить: %1".arg(modelData.action)
                    }
                    Rule {}
                }
            }
            Note {
                visible: page.qualityRows.length === 0
                text: "По выбранному фильтру проблем не найдено."
            }
        }
    }
    EditorialReportSection {
        objectName: "editorialBenchmarkSection"
        width: parent.width
        number: 5
        title: "Сравнение с индексом или фондом"
        toolbar: EditorialChoice {
            objectName: "editorialBenchmarkChoice"
            implicitWidth: 360
            model: page.benchmarkChoices
            textRole: "name"
            currentIndex: page.benchmarkIndex()
            onActivated: {
                const key = page.benchmarkChoices[currentIndex].key;
                if (key === "fund")
                    fundDialog.open();
                else
                    page.controller.selectBenchmarkIndex(key);
            }
        }
        Flow {
            width: parent.width
            spacing: 24
            EditorialAction {
                text: page.controller.benchmarkBusy ? "ЗАГРУЗКА…" : "ОБНОВИТЬ ИСТОРИЮ"
                enabled: !page.controller.benchmarkBusy && !!page.benchmark.canRefresh
                onClicked: page.controller.refreshBenchmark()
            }
            EditorialAction {
                visible: page.benchmarkSelection.kind === "fund"
                text: "ВЫБРАТЬ ДРУГОЙ ФОНД"
                onClicked: fundDialog.open()
            }
        }
        Note {
            visible: !page.benchmark.available
            text: page.benchmark.reason || "Выберите ориентир для сравнения."
        }
        Note {
            visible: !!page.controller.benchmarkError
            text: page.controller.benchmarkError
            color: "#b84932"
        }
        EditorialMetrics {
            width: parent.width
            height: implicitHeight
            visible: !!page.benchmark.available
            metrics: [
                {
                    label: "Ваш результат",
                    value: page.percent(page.benchmark.portfolioPercent)
                },
                {
                    label: "Результат ориентира",
                    value: page.percent(page.benchmark.benchmarkPercent)
                },
                {
                    label: "Разница результатов",
                    value: page.available(page.benchmark.differencePoints) ? Number(
                                                                                 page.benchmark.differencePoints).toFixed(
                                                                                 2).replace(".", ",") + " п.п." :
                                                                             "—"
                }
            ]
        }
        EditorialChart {
            width: parent.width
            height: 280
            visible: !!page.benchmark.available
            host: page.host
            percent: true
            series: [
                {
                    label: "Ваш результат",
                    rows: page.series(page.benchmark.points, "portfolio")
                },
                {
                    label: page.benchmarkSelection.symbol || "Ориентир",
                    dashed: true,
                    rows: page.series(page.benchmark.points, "benchmark")
                }
            ]
        }
        EditorialLegend {
            width: parent.width
            entries: [
                {
                    label: "Ваш результат"
                },
                {
                    label: page.benchmarkSelection.symbol || "Ориентир",
                    dashed: true
                }
            ]
        }
        Note {
            text: "Обе линии начинаются с нуля. Пополнения и выводы исключены из доходности портфеля."
        }
    }
    EditorialReportSection {
        objectName: "editorialDepositSection"
        width: parent.width
        number: 6
        title: "Сравнение доходности с вкладом"
        RowLayout {
            width: parent.width
            spacing: 24
            ColumnLayout {
                Layout.preferredWidth: 160
                EditorialText {
                    text: "ГОДОВАЯ СТАВКА, %"
                    font.family: "Cousine"
                    font.pixelSize: 12
                    color: "#59616a"
                }
                EditorialField {
                    id: depositRate
                    objectName: "editorialDepositRate"
                    Layout.fillWidth: true
                    text: (page.controller.performanceDeposit || ({})).rate || ""
                    placeholderText: "Укажите ставку"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 400
                EditorialText {
                    text: "КАПИТАЛИЗАЦИЯ"
                    font.family: "Cousine"
                    font.pixelSize: 12
                    color: "#59616a"
                }
                EditorialChoice {
                    id: depositMode
                    objectName: "editorialDepositMode"
                    Layout.fillWidth: true
                    model: ["Без капитализации", "Ежемесячная", "Ежедневная"]
                    currentIndex: Math.max(0, ["none", "monthly", "daily"].indexOf((page.controller.performanceDeposit
                                                                                    || ({})).capitalization))
                }
            }
            EditorialAction {
                text: "РАССЧИТАТЬ"
                Layout.alignment: Qt.AlignBottom
                onClicked: depositError.text = page.controller.setPerformanceDeposit(depositRate.text, ["none",
                                                                                                        "monthly",
                                                                                                        "daily"][depositMode.currentIndex])
                           ? "" : "Укажите ставку от 0 до 1000 %."
            }
        }
        Note {
            id: depositError
            color: "#b84932"
            visible: !!text
        }
        Note {
            visible: !page.deposit.available
            text: page.deposit.reason || "Укажите ставку и накопите дневные оценки выбранных счетов."
        }
        EditorialMetrics {
            width: parent.width
            height: implicitHeight
            visible: !!page.deposit.available
            metrics: [
                {
                    label: "Результат вложений",
                    value: page.amount(page.deposit.portfolioGainMinor)
                },
                {
                    label: "Доход условного вклада",
                    value: page.amount(page.deposit.depositGainMinor)
                },
                {
                    label: "Разница результатов",
                    value: page.amount(page.deposit.differenceMinor)
                }
            ]
        }
        EditorialChart {
            width: parent.width
            height: 280
            host: page.host
            currency: page.report.currency || page.controller.appCurrency
            visible: !!page.deposit.available
            series: [
                {
                    label: "Вложения",
                    rows: page.series(page.deposit.series, "portfolioMinor")
                },
                {
                    label: "Условный вклад",
                    dashed: true,
                    rows: page.series(page.deposit.series, "depositMinor")
                }
            ]
        }
        EditorialLegend {
            width: parent.width
            entries: [
                {
                    label: "Вложения"
                },
                {
                    label: "Условный вклад",
                    dashed: true
                }
            ]
        }
        Note {
            text: "Одинаковый начальный капитал и внешние пополнения/выводы. Ставка постоянная, вклад в валюте отчёта. Налоги и потеря процентов при досрочном закрытии не учитываются."
        }
    }
    EditorialReportSection {
        objectName: "editorialRiskSection"
        width: parent.width
        number: 7
        title: "Волатильность и просадки"
        EditorialMetrics {
            width: parent.width
            height: implicitHeight
            columns: page.host.width <= 850 ? 2 : 3
            metrics: [
                {
                    label: "Годовая волатильность",
                    value: page.percent(page.risk.annualVolatilityPercent),
                    hint: "Разброс дневной доходности"
                },
                {
                    label: "Максимальная просадка",
                    value: page.percent(page.risk.maximumDrawdownPercent),
                    hint: page.date(page.risk.peakDate) + " → " + page.date(page.risk.troughDate)
                },
                {
                    label: "Просадка на конец периода",
                    value: page.percent(page.risk.currentDrawdownPercent)
                },
                {
                    label: "Лучший день",
                    value: page.percent(page.risk.bestDayPercent)
                },
                {
                    label: "Худший день",
                    value: page.percent(page.risk.worstDayPercent)
                },
                {
                    label: "Дней в расчёте",
                    value: page.risk.available ? String(page.risk.returnDays || 0) : "—"
                }
            ]
        }
        EditorialChart {
            width: parent.width
            height: 248
            host: page.host
            percent: true
            series: [
                {
                    label: "Просадка",
                    rows: page.series(page.risk.drawdowns, "percent")
                }
            ]
        }
        EditorialLegend {
            width: parent.width
            entries: [
                {
                    label: "Просадка портфеля"
                }
            ]
        }
        Note {
            text: "Просадки считаются по связанной доходности с учётом пополнений и выводов. Это падение инвестиционного результата от предыдущего максимума."
        }
    }
    EditorialReportSection {
        objectName: "editorialStructureSection"
        width: parent.width
        number: 8
        title: "Структура вложений"
        toolbar: EditorialChoice {
            objectName: "editorialAllocationGroup"
            currentIndex: page.allocationIndex
            onActivated: page.allocationIndex = currentIndex
            model: ["По активам", "По типам активов", "По счетам", "По валютам счетов"]
        }
        GridLayout {
            width: parent.width
            columns: page.host.width <= 1150 ? 1 : 2
            columnSpacing: 48
            rowSpacing: 32
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 24
                EditorialDonut {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 224
                    Layout.preferredHeight: 224
                    visible: !!page.allocation.pieAvailable
                    slices: page.holdingRows.map(function (r) {
                        return {
                            title: r.label,
                            share: Number(r.percent || 0) / 100
                        };
                    })
                }
                Note {
                    Layout.fillWidth: true
                    visible: !page.allocation.pieAvailable
                    text: "Для круговых долей нужна полная положительная оценка вложений. Суммы приведены ниже."
                }
                Repeater {
                    model: page.holdingRows
                    RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            width: 8
                            height: 8
                            color: ["#031528", "#be7b56", "#b8ae99", "#738073", "#6b7fa3"][index % 5]
                        }
                        EditorialText {
                            Layout.fillWidth: true
                            text: modelData.label
                            font.pixelSize: 14
                        }
                        EditorialText {
                            text: page.amount(modelData.amountMinor)
                            font.family: "Cousine"
                            font.pixelSize: 14
                        }
                        EditorialText {
                            Layout.preferredWidth: 64
                            horizontalAlignment: Text.AlignRight
                            text: page.percent(page.allocation.pieAvailable ? modelData.percent : null)
                            font.family: "Cousine"
                            font.pixelSize: 12
                            color: "#59616a"
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 16
                EditorialText {
                    Layout.fillWidth: true
                    text: "Вклад активов в результат"
                    font.family: "PT Serif"
                    font.pixelSize: 24
                }
                Repeater {
                    model: page.contributions.items || []
                    Column {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 12
                        ListRow {
                            label: modelData.label
                            value: page.amount(modelData.amountMinor)
                            tone: modelData.amountMinor < 0 ? "#b84932" : "#2e5947"
                        }
                        Item {
                            width: parent.width
                            height: 12
                            Rectangle {
                                x: parent.width / 2
                                width: 1
                                height: 12
                                color: "#bbb5a8"
                            }
                            Rectangle {
                                readonly property real maximum: Math.max(1, ...(page.contributions.items || []).map(
                                                                             function (r) {
                                                                                 return Math.abs(Number(r.amountMinor));
                                                                             }))
                                width: Math.min(.48, Math.abs(Number(modelData.amountMinor)) / maximum * .48)
                                       * parent.width

                                height: 4
                                y: 4
                                x: modelData.amountMinor < 0 ? parent.width / 2 - width : parent.width / 2
                                color: modelData.amountMinor < 0 ? "#b84932" : "#031528"
                            }
                        }
                    }
                }
                Note {
                    Layout.fillWidth: true
                    text: "Валютная переоценка: %1 · Необъяснённая разница: %2".arg(page.amount(
                                                                                              page.contributions.fxMinor)).arg(
                              page.amount(page.contributions.unexplainedMinor))
                }
            }
        }
    }
    EditorialReportSection {
        objectName: "editorialPaymentsSection"
        width: parent.width
        number: 9
        title: "Аналитика выплат"
        EditorialMetrics {
            width: parent.width
            height: implicitHeight
            columns: 4
            metrics: [
                {
                    label: "Получено",
                    value: page.amount(page.payments.netMinor)
                },
                {
                    label: "До расходов",
                    value: page.amount(page.payments.grossMinor)
                },
                {
                    label: "Комиссии выплат",
                    value: page.amount(page.payments.feesMinor)
                },
                {
                    label: "Удержания выплат",
                    value: page.amount(page.payments.taxMinor)
                }
            ]
        }
        GridLayout {
            width: parent.width
            columns: page.host.width <= 1150 ? 1 : 2
            columnSpacing: 48
            rowSpacing: 32
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 8
                EditorialText {
                    text: "Получено по месяцам"
                    font.family: "PT Serif"
                    font.pixelSize: 24
                }
                Repeater {
                    model: page.payments.months || []
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 16
                        height: 48
                        EditorialText {
                            Layout.preferredWidth: 88
                            text: modelData.label
                            font.family: "Cousine"
                            font.pixelSize: 12
                            color: "#59616a"
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            Rectangle {
                                readonly property real maximum: Math.max(1, ...(page.payments.months || []).map(
                                                                             function (r) {
                                                                                 return Math.abs(Number(r.netMinor)
                                                                                                 || 0);
                                                                             }))
                                width: parent.width * Math.abs(Number(modelData.netMinor) || 0) / maximum
                                height: 4
                                color: "#031528"
                            }
                        }
                        EditorialText {
                            Layout.preferredWidth: 120
                            text: page.amount(modelData.netMinor)
                            horizontalAlignment: Text.AlignRight
                            font.family: "Cousine"
                            font.pixelSize: 12
                        }
                    }
                }
            }
            Column {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 16
                EditorialText {
                    text: "Источники выплат"
                    font.family: "PT Serif"
                    font.pixelSize: 24
                }
                Repeater {
                    model: page.payments.kinds || []
                    ListRow {
                        required property var modelData
                        label: modelData.label
                        value: page.amount(modelData.netMinor)
                    }
                }
                Note {
                    text: "Суммы до расходов, комиссии и удержания показываются, если они записаны отдельно."
                }
            }
        }
        EditorialCheck {
            id: paymentsOpen
            text: "Показать выплаты (%1)".arg(page.payments.count || 0)
        }
        Column {
            width: parent.width
            visible: paymentsOpen.checked
            spacing: 0
            Repeater {
                model: paymentsOpen.checked ? (page.payments.events || []) : []
                Column {
                    required property var modelData
                    width: parent.width
                    spacing: 8
                    ListRow {
                        label: page.date(modelData.date) + " · " + modelData.kind + " · " + modelData.asset
                        value: page.amount(modelData.netMinor)
                    }
                    Note {
                        text: modelData.account + " · " + page.amount(modelData.nativeNetMinor, modelData.currency)
                    }
                }
            }
        }
    }
    Column {
        width: parent.width
        spacing: 24
        Item {
            width: parent.width
            height: page.host.width <= 1500 ? 88 : 64
            EditorialSection {
                width: parent.width * .42
                height: 64
                number: 10
                title: "История расходов по месяцам"
            }
            EditorialText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: page.host.width <= 1500 ? 56 : 20
                height: 24
                text: "В СРЕДНЕМ %1".arg(page.amount(page.host.averageCompletedMonthExpense(
                                                               page.host.expenseRowsForYear(page.expenseYear)), "RUB"))
                font.family: "Cousine"
                font.pixelSize: 12
                color: "#59616a"
            }
            RowLayout {
                anchors.right: parent.right
                y: (64 - height) / 2
                spacing: 16
                EditorialAction {
                    text: "‹"
                    arrow: false
                    textSize: 24
                    enabled: page.expenseYear > page.host.expenseHistoryFirstYear()
                    onClicked: page.expenseYear--
                }
                EditorialText {
                    text: String(page.expenseYear)
                    font.family: "Cousine"
                    font.pixelSize: 14
                }
                EditorialAction {
                    text: "›"
                    arrow: false
                    textSize: 24
                    enabled: page.expenseYear < page.host.expenseHistoryLastYear()
                    onClicked: page.expenseYear++
                }
            }
        }
        Canvas {
            id: expenseChart
            width: parent.width
            height: 248
            property var rows: page.host.expenseRowsForYear(page.expenseYear)
            onRowsChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const max = Math.max(1, ...rows.map(function (r) {
                    return Number(r.totalMinor);
                }));
                const slot = width / 12;
                ctx.font = "12px Cousine";
                ctx.fillStyle = "#031528";
                rows.forEach(function (r, i) {
                    const h = Number(r.totalMinor) / max * 196;
                    ctx.fillRect(i * slot + slot * .2, 212 - h, slot * .6, h);
                    ctx.textAlign = "center";
                    ctx.fillText(Math.round(r.totalMinor / 100000) + " тыс.", (i + .5) * slot, 204 - h);
                    ctx.fillText(page.host.expenseMonthLabel(r.monthIndex), (i + .5) * slot, 232);
                });
            }
        }
    }
    Rectangle {
        width: parent.width
        height: 1
        color: "#031528"
    }
    GridLayout {
        width: parent.width
        columns: page.host.width <= 1150 ? 1 : 2
        columnSpacing: 48
        rowSpacing: 24
        EditorialReportSection {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            number: 11
            title: "История капитала в рублях"
            EditorialChart {
                width: parent.width
                height: 248
                host: page.host
                currency: "RUB"
                series: [
                    {
                        rows: page.series(page.controller.capitalHistoryRub, "totalMinor")
                    }
                ]
            }
        }
        EditorialReportSection {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            number: 12
            title: "Капитал в выбранной валюте"
            toolbar: EditorialChoice {
                implicitWidth: 96
                model: ["USD", "EUR", "CNY"]
                currentIndex: Math.max(0, model.indexOf(page.controller.analyticsCurrency))
                onActivated: page.controller.analyticsCurrency = currentText
            }
            EditorialChart {
                width: parent.width
                height: 248
                host: page.host
                currency: page.controller.analyticsCurrency
                series: [
                    {
                        rows: page.series(page.controller.capitalHistoryAnalyticsCurrency, "totalMinor")
                    }
                ]
            }
        }
    }
    Dialog {
        id: fundDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(620, parent ? parent.width - 32 : 620)
        modal: true
        padding: 24
        title: "Биржевой фонд для сравнения"
        contentItem: ColumnLayout {
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: fundQuery
                    Layout.fillWidth: true
                    placeholderText: "Название или обозначение фонда"
                    onAccepted: page.controller.searchBenchmarkFunds(text)
                }
                Button {
                    text: "Найти"
                    enabled: !page.controller.benchmarkSearchBusy
                    onClicked: page.controller.searchBenchmarkFunds(fundQuery.text)
                }
            }
            Label {
                visible: page.controller.benchmarkSearchBusy
                text: "Ищем биржевые фонды…"
            }
            Label {
                visible: !!page.controller.benchmarkSearchError
                text: page.controller.benchmarkSearchError
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                clip: true
                model: page.controller.benchmarkSearchResults
                delegate: ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.symbol + " · " + modelData.name
                    onClicked: {
                        page.controller.selectBenchmarkFund(modelData.index);
                        fundDialog.close();
                    }
                }
            }
            Button {
                text: "Закрыть"
                onClicked: fundDialog.close()
            }
        }
    }
}
