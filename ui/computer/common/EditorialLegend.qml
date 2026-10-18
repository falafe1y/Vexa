import QtQuick
import QtQuick.Layouts
import "../dashboard"

RowLayout {
    id: legend
    property var entries: []
    spacing: 24
    implicitHeight: 24
    Repeater {
        model: legend.entries
        delegate: RowLayout {
            required property var modelData
            spacing: 8
            Canvas {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 8
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = "#031528";
                    ctx.lineWidth = 2;
                    ctx.setLineDash(modelData.dashed ? [6, 4] : modelData.dotted ? [2, 4] : []);
                    ctx.beginPath();
                    ctx.moveTo(0, 4);
                    ctx.lineTo(width, 4);
                    ctx.stroke();
                }
            }
            EditorialText {
                text: modelData.label
                font.family: "Cousine"
                font.pixelSize: 12
                color: "#59616a"
            }
        }
    }
    Item {
        Layout.fillWidth: true
    }
}
