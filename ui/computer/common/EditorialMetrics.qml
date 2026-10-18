import QtQuick
import "../dashboard"

Item {
    id: grid
    property var metrics: []
    property int columns: 3
    property int cellHeight: 136
    readonly property int rowCount: Math.ceil(metrics.length / columns)
    implicitHeight: rowCount * cellHeight
    Rectangle {
        width: parent.width
        height: 1
        color: "#031528"
    }
    Repeater {
        model: grid.metrics
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property int col: index % grid.columns
            readonly property int row: Math.floor(index / grid.columns)
            readonly property int inset: grid.width <= 1200 ? 16 : 24
            x: Math.round(grid.width * col / grid.columns)
            y: row * grid.cellHeight
            width: Math.round(grid.width * (col + 1) / grid.columns) - x
            height: grid.cellHeight
            objectName: "editorialMetricCell"
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                visible: cell.col < grid.columns - 1
                color: "#bbb5a8"
            }
            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                visible: cell.row < grid.rowCount - 1
                color: "#bbb5a8"
            }
            Column {
                objectName: "editorialMetricContent"
                x: cell.col === 0 ? 0 : cell.inset
                y: 24
                width: parent.width - x - (cell.col === grid.columns - 1 ? 0 : cell.inset)
                spacing: 4
                EditorialText {
                    width: parent.width
                    height: 24
                    text: cell.modelData.label.toUpperCase()
                    font.family: "Cousine"
                    font.pixelSize: 12
                    color: "#59616a"
                }
                EditorialText {
                    width: parent.width
                    height: 48
                    text: cell.modelData.value
                    font.family: "PT Serif"
                    font.pixelSize: grid.width < 1000 ? 28 : grid.width < 1300 ? 32 : 36
                    color: cell.modelData.color || "#031528"
                }
                EditorialText {
                    width: parent.width
                    height: 24
                    text: cell.modelData.hint || ""
                    font.pixelSize: 14
                    color: "#59616a"
                }
            }
        }
    }
    Rectangle {
        y: parent.height - 1
        width: parent.width
        height: 1
        color: "#031528"
    }
}
