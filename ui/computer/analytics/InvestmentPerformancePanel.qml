import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

Rectangle {
    id: panel
    required property var controller
    property color surface: (Appearance.desktop ? "#f3eddf" : "#FFFFF8")
    property color ink: "#031528"
    property color muted: (Appearance.desktop ? "#59616a" : "#687483")
    property color line: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color positive: "#3F735F"
    property color negative: (Appearance.desktop ? "#b84932" : "#B94F48")
    readonly property var report: controller ? (controller.investmentPerformance || ({})) : ({})
    readonly property var choices: [{id: "", name: "Все инвестиционные счета"}, {id: "group:brokerage", name: "Все брокерские счета"}, {id: "group:deposit", name: "Все вклады"}].concat(controller ? (controller.performanceAccounts || []) : [])
    readonly property var warnings: report.warnings || []
    property bool detailsOpen: false
    color: surface
    border.color: ink
    radius: Appearance.desktop ? 0 : 12
    implicitHeight: content.implicitHeight + 40

    function available(n) { return n !== undefined && n !== null && isFinite(Number(n)) }
    function amount(n) { return available(n) ? Number(n / 100).toLocaleString(Qt.locale(), 'f', 2) + " " + (report.currency || "") : "—" }
    function percent(n) { return available(n) ? Number(n).toLocaleString(Qt.locale(), 'f', 2) + " %" : "—" }
    function date(s) { return s ? s.substr(8, 2) + "." + s.substr(5, 2) + "." + s.substr(0, 4) : "—" }

    EditorialColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: Appearance.desktop ? 16 : 14
        EditorialRowLayout {
            Layout.fillWidth: true
            EditorialDialogTitle { text: "Доходность"; color: panel.ink;   Layout.fillWidth: true }
            StyledComboBox {
                id: account; objectName: "account"
                Layout.preferredWidth: Appearance.desktop ? 292 : 290
                model: panel.choices
                textRole: "name"
                currentIndex: {
                    for (var i = 0; i < panel.choices.length; ++i)
                        if (panel.choices[i].id === (panel.controller ? panel.controller.performanceAccountId : "")) return i
                    return 0
                }
                onActivated: panel.controller.setPerformanceAccount(panel.choices[currentIndex].id)
            }
        }
        EditorialLabel {
            Layout.fillWidth: true
            color: panel.muted
            wrapMode: Text.WordWrap
            text: "Действующие брокерские счета и вклады · Валюта отчёта: %1".arg(panel.report.currency || "")
                + "\n" + "Оценки: %1 — %2 · Дней с оценкой: %3".arg(panel.date(panel.report.from)).arg(panel.date(panel.report.to)).arg(panel.report.observationCount || 0)
        }
        GridLayout {
            Layout.fillWidth: true
            columns: panel.width < 700 ? 2 : 3
            columnSpacing: 12
            rowSpacing: 12
            Repeater {
                model: [
                    {title: "Результат за период", value: panel.amount(panel.report.gainMinor), hint: "Изменение капитала без пополнений и выводов"},
                    {title: "Доходность за период", value: panel.percent(panel.report.periodPercent), hint: "По дневным оценкам, с учётом денежных потоков"},
                    {title: "Годовой эквивалент", value: panel.percent(panel.report.annualPercent), hint: "Пересчёт темпа роста на год, без прогноза"},
                    {title: "Прибыль после продаж", value: panel.amount(panel.report.realizedMinor), hint: panel.available(panel.report.realizedMinor) ? "Продажи и расчёты по контрактам, после учтённых расходов; по фильтру дат" : "Известная часть: %1".arg(panel.amount(panel.report.knownRealizedMinor))},
                    {title: "Прибыль открытых позиций", value: panel.amount(panel.report.unrealizedMinor), hint: "На конец периода, относительно стоимости приобретения"},
                    {title: "После заданной инфляции", value: panel.percent(panel.report.realPercent), hint: "Доходность за период по указанной ниже годовой ставке"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 152
                    color: "transparent"
                    border.color: panel.line
                    radius: Appearance.desktop ? 0 : 8
                    EditorialColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: Appearance.desktop ? 8 : 6
                        EditorialRowLayout {
                            Layout.fillWidth: true
                            EditorialLabel { Layout.fillWidth: true; text: modelData.title; color: panel.muted; wrapMode: Text.WordWrap }
                            InvestmentMetricHelp { metric: ["gain","period","annual","realized","unrealized","inflation"][index]; displayValue: modelData.value; ink: panel.ink; muted: panel.muted }
                        }
                        EditorialLabel { Layout.fillWidth: true; text: modelData.value; color: panel.ink; font.pixelSize: 24; font.bold: true; elide: Text.ElideRight }
                        EditorialLabel { Layout.fillWidth: true; Layout.fillHeight: true; text: modelData.hint; color: panel.muted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    }
                }
            }
        }
        EditorialRowLayout {
            Layout.fillWidth: true
            EditorialLabel { text: "Заданная инфляция, % в год:"; color: panel.ink }
            TextField {
                id: inflation; objectName: "inflation"
                Layout.preferredWidth: Appearance.desktop ? 112 : 110
                text: panel.controller ? panel.controller.performanceInflation : ""
                placeholderText: "Не задана"
                selectByMouse: true
                onAccepted: saveInflation.clicked()
            }
            StyledButton {
                id: saveInflation; objectName: "saveInflation"
                text: "Применить"
                onClicked: inflationError.text = panel.controller.setPerformanceInflation(inflation.text) ? "" : "Введите ставку больше −100 и не выше 1000 %; до 4 знаков после запятой."
            }
            Item { Layout.fillWidth: true }
        }
        EditorialLabel { id: inflationError; visible: text.length > 0; color: panel.negative; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        EditorialLabel { Layout.fillWidth: true; text: "Ставка — ваше допущение, одинаковое на весь период. Это не исторический индекс потребительских цен."; color: panel.muted; font.pixelSize: 12; wrapMode: Text.WordWrap }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: panel.line }
        InvestmentDataQualityPanel {
            Layout.fillWidth: true
            quality: panel.report.dataQuality || ({})
            ink: panel.ink; muted: panel.muted; line: panel.line; negative: panel.negative
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: panel.line }
        InvestmentBenchmarkPanel {
            Layout.fillWidth: true
            controller: panel.controller
            ink: panel.ink
            muted: panel.muted
            line: panel.line
            accent: panel.positive
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: panel.line }
        InvestmentDepositPanel {
            Layout.fillWidth: true
            controller: panel.controller
            ink: panel.ink; muted: panel.muted; line: panel.line; accent: panel.positive
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: panel.line }
        InvestmentRiskPanel {
            Layout.fillWidth: true
            risk: panel.report.risk || ({})
            ink: panel.ink
            muted: panel.muted
            line: panel.line
            negative: panel.negative
            positive: panel.positive
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: panel.line }
        InvestmentStructurePanel {
            Layout.fillWidth: true
            allocation: panel.report.allocation || ({})
            contributions: panel.report.contributions || ({})
            currency: panel.report.currency || "RUB"
            ink: panel.ink; muted: panel.muted; line: panel.line
            positive: panel.positive; negative: panel.negative
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: panel.line }
        InvestmentPaymentsPanel {
            Layout.fillWidth: true
            payments: panel.report.payments || ({})
            currency: panel.report.currency || "RUB"
            ink: panel.ink; muted: panel.muted; line: panel.line
            positive: panel.positive; negative: panel.negative
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: panel.line }
        EditorialLabel { text: "Разложение результата за период"; font.pixelSize: 17; font.bold: true; color: panel.ink }
        EditorialLabel {
            Layout.fillWidth: true
            text: "Чистые пополнения и выводы: %1 · Изменение прибыли открытых позиций: %2".arg(panel.amount(panel.report.externalFlowMinor)).arg(panel.amount(panel.report.unrealizedChangeMinor))
            wrapMode: Text.WordWrap
            color: panel.muted
        }
        EditorialRowLayout {
            InvestmentMetricHelp { metric: "flow"; displayValue: panel.amount(panel.report.externalFlowMinor); ink: panel.ink; muted: panel.muted }
            EditorialLabel { text: "Пополнения и выводы"; color: panel.muted }
            InvestmentMetricHelp { metric: "unrealized_change"; displayValue: panel.amount(panel.report.unrealizedChangeMinor); ink: panel.ink; muted: panel.muted }
            EditorialLabel { text: "Изменение открытой прибыли"; color: panel.muted }
        }
        Repeater {
            model: panel.available(panel.report.gainMinor) ? (panel.report.breakdown || []) : []
            delegate: EditorialRowLayout {
                required property var modelData
                Layout.fillWidth: true
                EditorialLabel { text: modelData.label + (modelData.complete ? "" : " · известная часть"); color: panel.ink; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                EditorialLabel { text: panel.amount(modelData.amountMinor); color: modelData.amountMinor < 0 ? panel.negative : panel.positive; font.bold: true }
                InvestmentMetricHelp { metric: "part_" + modelData.code; displayValue: panel.amount(modelData.amountMinor); ink: panel.ink; muted: panel.muted }
            }
        }
        EditorialLabel {
            visible: !panel.available(panel.report.gainMinor)
            text: "Разложение появится, когда будут известны результат периода и денежные потоки."
            color: panel.muted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        EditorialLabel {
            Layout.fillWidth: true
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            text: "Продажи и переоценка показаны до отдельно указанных комиссий и удержаний. Валютная строка отражает изменение курса валюты счёта к валюте отчёта; курс валюты самого инструмента включён в результат позиции."
            color: panel.muted
        }
        StyledButton { visible: panel.warnings.length > 0; text: panel.detailsOpen ? "Скрыть пояснения" : "Пояснения к расчёту (%1)".arg(panel.warnings.length); onClicked: panel.detailsOpen = !panel.detailsOpen }
        EditorialLabel {
            visible: panel.detailsOpen && panel.warnings.length > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: panel.muted
            text: panel.warnings.join("\n")
        }
    }
}
