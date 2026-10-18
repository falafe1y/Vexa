import QtQuick
import QtQuick.Controls

Canvas {
    id: chart
    property var series: []
    property var host: null
    property string currency: "RUB"
    property bool percent: false
    property int hovered: -1
    readonly property int leftMargin: width < 700 ? 80 : 96
    readonly property int rightMargin: 16
    readonly property int topMargin: 20
    readonly property int bottomMargin: 36
    implicitHeight: 280
    onSeriesChanged: {
        hovered = -1;
        requestPaint();
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    function valid(value) {
        return value !== null && value !== undefined && isFinite(Number(value));
    }
    function shortDate(value) {
        const d = new Date(value);
        return isNaN(d.getTime()) ? "" : Qt.formatDate(d, "dd.MM.yyyy");
    }
    function label(value) {
        if (percent)
            return Number(value).toLocaleString(Qt.locale("ru_RU"), "f", 1) + " %";
        return host ? host.capitalAxisMoney(value, currency) : Math.round(value / 100).toLocaleString(Qt.locale(
                                                                                                          "ru_RU"));
    }
    function hoverText() {
        if (!series.length || hovered < 0)
            return "";
        const first = series[0].rows || [], index = Math.min(hovered, first.length - 1);
        if (index < 0)
            return "";
        const lines = [shortDate(first[index].date)];
        series.forEach(function (s) {
            const row = (s.rows || [])[index];
            if (!row || !valid(row.value))
                return;
            lines.push((s.label || "") + ": " + (percent ? Number(row.value).toFixed(2) + " %" : host.money(row.value,
                                                                                                            currency, false)));
        });
        return lines.join("\n");
    }
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width <= leftMargin + rightMargin || height <= topMargin + bottomMargin)
            return;
        const values = [];
        series.forEach(function (s) {
            (s.rows || []).forEach(function (r) {
                if (chart.valid(r.value))
                    values.push(Number(r.value));
            });
        });
        if (!values.length)
            return;
        let low = Math.min.apply(Math, values), high = Math.max.apply(Math, values);
        const pad = Math.max((high - low) * .15, Math.abs(high) * .025, percent ? .25 : 100);
        low -= pad;
        high += pad;
        const pw = width - leftMargin - rightMargin, ph = height - topMargin - bottomMargin;
        ctx.font = "12px Cousine";
        ctx.textBaseline = "middle";
        for (let i = 0; i <= 5; ++i) {
            const y = topMargin + ph * i / 5, value = high - (high - low) * i / 5;
            ctx.strokeStyle = "#bbb5a8";
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(leftMargin, y);
            ctx.lineTo(width - rightMargin, y);
            ctx.stroke();
            ctx.fillStyle = "#59616a";
            ctx.textAlign = "right";
            ctx.fillText(label(value), leftMargin - 16, y);
        }
        series.forEach(function (s) {
            const rows = s.rows || [];
            ctx.strokeStyle = "#031528";
            ctx.lineWidth = 2;
            ctx.setLineDash(s.dashed ? [8, 6] : s.dotted ? [2, 4] : []);
            ctx.beginPath();
            let connected = false;
            for (let i = 0; i < rows.length; ++i) {
                if (!chart.valid(rows[i].value)) {
                    connected = false;
                    continue;
                }
                const x = leftMargin + pw * i / Math.max(1, rows.length - 1), y = topMargin + ph * (1 - (Number(
                                                                                                             rows[i].value)
                                                                                                         - low) / (high
                                                                                                                   - low));
                if (connected)
                    ctx.lineTo(x, y);
                else
                    ctx.moveTo(x, y);
                connected = true;
            }
            ctx.stroke();
            ctx.setLineDash([]);
        });
        const rows = series.length ? series[0].rows || [] : [];
        ctx.fillStyle = "#59616a";
        ctx.textBaseline = "top";
        const labels = rows.length < 3 ? 2 : 3;
        for (let i = 0; i < labels && rows.length; ++i) {
            const index = Math.round((rows.length - 1) * i / (labels - 1));
            ctx.textAlign = i === 0 ? "left" : i === labels - 1 ? "right" : "center";
            ctx.fillText(shortDate(rows[index].date), leftMargin + pw * i / (labels - 1), height - 20);
        }
        if (hovered >= 0 && rows.length > 1) {
            const x = leftMargin + pw * hovered / (rows.length - 1);
            ctx.strokeStyle = "#59616a";
            ctx.lineWidth = 1;
            ctx.setLineDash([2, 4]);
            ctx.beginPath();
            ctx.moveTo(x, topMargin);
            ctx.lineTo(x, height - bottomMargin);
            ctx.stroke();
            ctx.setLineDash([]);
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: function (mouse) {
            const n = chart.series.length ? (chart.series[0].rows || []).length : 0;
            chart.hovered = n > 0 && mouse.x >= chart.leftMargin && mouse.x <= chart.width - chart.rightMargin
                    && mouse.y >= chart.topMargin && mouse.y <= chart.height - chart.bottomMargin ? Math.max(0, Math.min(
                                                                                                                 n - 1, Math.round(
                                                                                                                     (mouse.x
                                                                                                                      - chart.leftMargin)
                                                                                                                     / Math.max(
                                                                                                                         1, chart.width
                                                                                                                         - chart.leftMargin
                                                                                                                         - chart.rightMargin)
                                                                                                                     * (n - 1)))) :
                                                                                                    -1;
            chart.requestPaint();
        }
        onExited: {
            chart.hovered = -1;
            chart.requestPaint();
        }
        ToolTip.visible: chart.hovered >= 0
        ToolTip.text: chart.hoverText()
    }
}
