import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

Item {
    id: panel
    property var risk: ({})
    property color ink: "#031528"
    property color muted: (Appearance.desktop ? "#59616a" : "#687483")
    property color line: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color negative: (Appearance.desktop ? "#b84932" : "#B94F48")
    property color positive: "#3F735F"
    readonly property var points: risk.drawdowns || []
    implicitHeight: content.implicitHeight

    function available(n) { return n !== undefined && n !== null && isFinite(Number(n)) }
    function percent(n) { return available(n) ? Number(n).toLocaleString(Qt.locale(), 'f', 2) + " %" : "—" }
    function date(s) { return s ? s.substr(8, 2) + "." + s.substr(5, 2) + "." + s.substr(0, 4) : "—" }
    onPointsChanged: chart.requestPaint()
    onLineChanged: chart.requestPaint()
    onNegativeChanged: chart.requestPaint()

    EditorialColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 16
        EditorialLabel { text: "Колебания и просадки"; color: panel.ink; font.pixelSize: 17; font.bold: true }
        GridLayout {
            Layout.fillWidth: true
            columns: panel.width < 700 ? 2 : 3
            columnSpacing: 12
            rowSpacing: 12
            Repeater {
                model: [
                    {title: "Годовая волатильность", value: panel.percent(panel.risk.annualVolatilityPercent), hint: "Разброс дневной доходности, приведённый к году"},
                    {title: "Максимальная просадка", value: panel.percent(panel.risk.maximumDrawdownPercent), hint: panel.risk.peakDate ? panel.date(panel.risk.peakDate) + " → " + panel.date(panel.risk.troughDate) : "Падение от предыдущего максимума за выбранный период"},
                    {title: "Просадка на конец периода", value: panel.percent(panel.risk.currentDrawdownPercent), hint: "Ниже максимума, достигнутого в этом периоде"},
                    {title: "Лучший день", value: panel.percent(panel.risk.bestDayPercent), hint: panel.date(panel.risk.bestDay)},
                    {title: "Худший день", value: panel.percent(panel.risk.worstDayPercent), hint: panel.date(panel.risk.worstDay)},
                    {title: "Дней доходности в расчёте", value: panel.risk.available ? String(panel.risk.returnDays || 0) : "—", hint: "Дни, когда была положительная база для расчёта"}
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
                            InvestmentMetricHelp { metric: ["volatility","maximum_drawdown","current_drawdown","best_day","worst_day","risk_days"][index]; displayValue: modelData.value; ink: panel.ink; muted: panel.muted }
                        }
                        EditorialLabel { Layout.fillWidth: true; text: modelData.value; color: panel.ink; font.pixelSize: 22; font.bold: true; elide: Text.ElideRight }
                        EditorialLabel { Layout.fillWidth: true; Layout.fillHeight: true; text: modelData.hint; color: panel.muted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    }
                }
            }
        }
        EditorialLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: panel.muted
            text: !panel.risk.available ? "Для расчёта нужна непрерывная история оценок и известные денежные потоки. Причины пропусков указаны в пояснениях к расчёту."
                : !panel.available(panel.risk.annualVolatilityPercent) ? "Для волатильности нужны минимум два дня доходности — три дневные оценки. Просадки и лучший/худший день уже доступны."
                : "Выборочное отклонение дневной доходности × √365,25. Дни с нулевым капиталом и без движений исключены из волатильности. Короткая история даёт менее устойчивую оценку."
        }
        EditorialLabel {
            visible: !!panel.risk.available && panel.risk.maximumDrawdownPercent > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: panel.muted
            text: panel.risk.recoveryDate ? "Максимальная просадка восстановилась: %1".arg(panel.date(panel.risk.recoveryDate))
                : "Максимальная просадка не восстановилась к концу выбранного периода."
        }
        EditorialLabel { text: "Просадка относительно предыдущего максимума"; color: panel.ink; font.bold: true; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        Item {
            id: plot
            Layout.fillWidth: true
            Layout.preferredHeight: 236
            visible: panel.points.length >= 2
            readonly property real leftMargin: Appearance.desktop ? 68 : 65
            readonly property real rightMargin: 16
            readonly property real topMargin: 12
            readonly property real bottomMargin: Appearance.desktop ? 32 : 30
            readonly property real plotWidth: Math.max(1, width - leftMargin - rightMargin)
            readonly property real plotHeight: Math.max(1, height - topMargin - bottomMargin)
            readonly property real depth: Math.min(100, Math.max(1, (panel.risk.maximumDrawdownPercent || 0) < 5 ? Math.ceil(panel.risk.maximumDrawdownPercent || 0) : Math.ceil((panel.risk.maximumDrawdownPercent || 0) / 5) * 5))
            property int hovered: -1
            onWidthChanged: chart.requestPaint()
            onHeightChanged: chart.requestPaint()
            onDepthChanged: chart.requestPaint()
            Canvas {
                id: chart
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var data = panel.points
                    if (data.length < 2) return
                    ctx.strokeStyle = panel.line
                    ctx.lineWidth = 1
                    for (var grid = 0; grid < 5; ++grid) {
                        var gy = plot.topMargin + plot.plotHeight * grid / 4
                        ctx.beginPath(); ctx.moveTo(plot.leftMargin, gy); ctx.lineTo(width - plot.rightMargin, gy); ctx.stroke()
                    }
                    var xAt = function(i) { return plot.leftMargin + plot.plotWidth * i / (data.length - 1) }
                    var yAt = function(i) { return plot.topMargin - data[i].percent / plot.depth * plot.plotHeight }
                    ctx.beginPath(); ctx.moveTo(xAt(0), plot.topMargin)
                    for (var i = 0; i < data.length; ++i) ctx.lineTo(xAt(i), yAt(i))
                    ctx.lineTo(xAt(data.length - 1), plot.topMargin); ctx.closePath()
                    ctx.fillStyle = Qt.rgba(panel.negative.r, panel.negative.g, panel.negative.b, 0.12); ctx.fill()
                    ctx.beginPath(); ctx.moveTo(xAt(0), yAt(0))
                    for (var j = 1; j < data.length; ++j) ctx.lineTo(xAt(j), yAt(j))
                    ctx.strokeStyle = panel.negative; ctx.lineWidth = 2; ctx.stroke()
                    if (plot.hovered >= 0 && plot.hovered < data.length) {
                        var hx = xAt(plot.hovered)
                        ctx.beginPath(); ctx.moveTo(hx, plot.topMargin); ctx.lineTo(hx, plot.topMargin + plot.plotHeight)
                        ctx.strokeStyle = panel.muted; ctx.lineWidth = 1; ctx.stroke()
                    }
                }
            }
            Repeater {
                model: 5
                delegate: EditorialLabel {
                    required property int index
                    x: 0
                    y: plot.topMargin + plot.plotHeight * index / 4 - height / 2
                    width: plot.leftMargin - 8
                    horizontalAlignment: Text.AlignRight
                    color: panel.muted
                    font.pixelSize: 12
                    text: Number(-plot.depth * index / 4).toLocaleString(Qt.locale(), 'f', 1) + " %"
                }
            }
            EditorialLabel { x: plot.leftMargin; anchors.bottom: parent.bottom; text: panel.date(panel.points.length ? panel.points[0].date : ""); color: panel.muted; font.pixelSize: 12 }
            EditorialLabel { anchors.right: parent.right; anchors.rightMargin: plot.rightMargin; anchors.bottom: parent.bottom; text: panel.date(panel.points.length ? panel.points[panel.points.length - 1].date : ""); color: panel.muted; font.pixelSize: 12 }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onPositionChanged: function(mouse) {
                    plot.hovered = mouse.x >= plot.leftMargin && mouse.x <= width - plot.rightMargin
                        && mouse.y >= plot.topMargin && mouse.y <= height - plot.bottomMargin
                        ? Math.max(0, Math.min(panel.points.length - 1, Math.round((mouse.x - plot.leftMargin) / plot.plotWidth * (panel.points.length - 1)))) : -1
                    chart.requestPaint()
                }
                onExited: { plot.hovered = -1; chart.requestPaint() }
                ToolTip.visible: plot.hovered >= 0 && plot.hovered < panel.points.length
                ToolTip.text: plot.hovered >= 0 && plot.hovered < panel.points.length
                    ? panel.date(panel.points[plot.hovered].date) + " · " + panel.percent(panel.points[plot.hovered].percent) : ""
            }
        }
        EditorialLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: panel.muted
            font.pixelSize: 12
            text: "Просадки считаются по связанной доходности с учётом пополнений и выводов. Это падение инвестиционного результата, а не денежного остатка. Начальный максимум задан на начало выбранного периода; оценка текущего дня может быть неполной."
        }
    }
}
