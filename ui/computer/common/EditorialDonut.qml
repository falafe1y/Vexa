import QtQuick

Canvas {
    id: donut
    property var slices: []
    property var colors: ["#031528", "#be7b56", "#b8ae99", "#738073", "#6b7fa3", "#a98f89"]
    implicitWidth: 224
    implicitHeight: 224
    onSlicesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const radius = Math.min(width, height) / 2 - 2, stroke = Math.round(radius * .32);
        let start = -Math.PI / 2, sum = 0;
        for (let i = 0; i < slices.length; ++i)
            sum += Math.max(0, Number(slices[i].share || 0));
        if (!sum) {
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, radius - stroke / 2, 0, Math.PI * 2);
            ctx.strokeStyle = "#bbb5a8";
            ctx.lineWidth = stroke;
            ctx.stroke();
            return;
        }
        for (let i = 0; i < slices.length; ++i) {
            const share = Math.max(0, Number(slices[i].share || 0));
            if (!share)
                continue;
            const end = start + share / sum * 2 * Math.PI;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, radius - stroke / 2, start, end);
            ctx.strokeStyle = slices[i].color || colors[i % colors.length];
            ctx.lineWidth = stroke;
            ctx.stroke();
            start = end;
        }
    }
}
