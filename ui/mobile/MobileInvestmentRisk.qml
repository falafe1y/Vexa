import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: panel

    property var risk: ({})

    readonly property var points: risk.drawdowns || []
    readonly property var xFractions: points.map(function (row, index) {
        return points.length > 1 ? index / (points.length - 1) : 0.5;
    })
    readonly property var chartSeries: [
        {
            values: points.map(function (row) {
                return -Number(row.percent);
            }),
            color: MobileTheme.red,
            width: 2
        }
    ]

    function available(value) {
        return value !== undefined && value !== null && isFinite(Number(value));
    }
    function percent(value) {
        return available(value) ? Number(value).toLocaleString(MobileFormat.locale(), "f", 2) + " %" : "—";
    }
    function date(value) {
        return value ? value.substr(8, 2) + "." + value.substr(5, 2) + "." + value.substr(0, 4) : "—";
    }

    spacing: 12

    MobileText {
        font.family: MobileTheme.serif
        Layout.fillWidth: true
        text: "Колебания и просадки"
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeHeading
        font.weight: Font.DemiBold
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 12
        rowSpacing: 12

        Repeater {
            model: [
                {
                    title: "Годовая волатильность",
                    value: panel.percent(panel.risk.annualVolatilityPercent),
                    hint: "Разброс дневной доходности, приведённый к году",
                    metric: "volatility"
                },
                {
                    title: "Максимальная просадка",
                    value: panel.percent(panel.risk.maximumDrawdownPercent),
                    hint: panel.risk.peakDate ? panel.date(panel.risk.peakDate) + " → " + panel.date(panel.risk.troughDate) : "Падение от предыдущего максимума за выбранный период",
                    metric: "maximum_drawdown"
                },
                {
                    title: "Просадка на конец периода",
                    value: panel.percent(panel.risk.currentDrawdownPercent),
                    hint: "Ниже максимума, достигнутого в этом периоде",
                    metric: "current_drawdown"
                },
                {
                    title: "Лучший день",
                    value: panel.percent(panel.risk.bestDayPercent),
                    hint: panel.date(panel.risk.bestDay),
                    metric: "best_day"
                },
                {
                    title: "Худший день",
                    value: panel.percent(panel.risk.worstDayPercent),
                    hint: panel.date(panel.risk.worstDay),
                    metric: "worst_day"
                },
                {
                    title: "Дней доходности в расчёте",
                    value: panel.risk.available ? String(panel.risk.returnDays || 0) : "—",
                    hint: "Дни, когда была положительная база для расчёта",
                    metric: "risk_days"
                }
            ]

            delegate: MobileCard {
                required property var modelData

                Layout.fillWidth: true
                cardPadding: 12
                gap: 8

                RowLayout {
                    Layout.fillWidth: true
                    MobileText {
                        font.family: MobileTheme.mono
                        Layout.fillWidth: true
                        text: modelData.title
                        wrapMode: Text.Wrap
                        color: MobileTheme.muted
                        font.pixelSize: MobileTheme.sizeCaption
                    }
                    MobileInfoButton {
                        metric: modelData.metric
                        displayValue: modelData.value
                    }
                }
                MobileText {
                    font.family: MobileTheme.serif
                    Layout.fillWidth: true
                    text: modelData.value
                    elide: Text.ElideRight
                    color: MobileTheme.accent
                    font.pixelSize: MobileTheme.sizeTitle
                    font.weight: Font.Bold
                }
                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: modelData.hint
                    wrapMode: Text.Wrap
                    color: MobileTheme.muted
                    font.pixelSize: MobileTheme.sizeCaption
                }
            }
        }
    }

    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
        text: !panel.risk.available ? "Для расчёта нужна непрерывная история оценок и известные денежные потоки. Причины пропусков указаны в пояснениях к расчёту." : !panel.available(panel.risk.annualVolatilityPercent) ? "Для волатильности нужны минимум два дня доходности — три дневные оценки. Просадки и лучший/худший день уже доступны." : "Выборочное отклонение дневной доходности × √365,25. Дни с нулевым капиталом и без движений исключены из волатильности. Короткая история даёт менее устойчивую оценку."
    }

    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        visible: !!panel.risk.available && panel.risk.maximumDrawdownPercent > 0
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
        text: panel.risk.recoveryDate ? "Максимальная просадка восстановилась: %1".arg(panel.date(panel.risk.recoveryDate)) : "Максимальная просадка не восстановилась к концу выбранного периода."
    }

    MobileText {
        font.family: MobileTheme.sans
        Layout.fillWidth: true
        text: "Просадка относительно предыдущего максимума"
        wrapMode: Text.Wrap
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeBody
        font.weight: Font.DemiBold
    }

    MobileCard {
        visible: panel.points.length >= 2
        Layout.fillWidth: true
        gap: 8

        MobileSeriesChart {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            series: panel.chartSeries
            xFractions: panel.xFractions
            xLabels: [
                {
                    fraction: 0,
                    text: panel.date(panel.points.length ? panel.points[0].date : ""),
                    align: "left"
                },
                {
                    fraction: 1,
                    text: panel.date(panel.points.length ? panel.points[panel.points.length - 1].date : ""),
                    align: "right"
                }
            ]
            tooltips: panel.points.map(function (row) {
                return panel.date(row.date) + " · " + panel.percent(row.percent);
            })
            formatValue: function (value) {
                return Number(value).toLocaleString(MobileFormat.locale(), "f", 1) + " %";
            }
        }
    }

    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
        text: "Просадки считаются по связанной доходности с учётом пополнений и выводов. Это падение инвестиционного результата, а не денежного остатка. Начальный максимум задан на начало выбранного периода; оценка текущего дня может быть неполной."
    }
}
