import QtQuick
import QtQuick.Controls
import "../dashboard"

Item {
    id: table
    objectName: "editorialOperationsTable"
    required property var host
    property var rows: []
    property var viewport: null
    property var selectedKeys: ({})
    readonly property var selectedRows: rows.filter(function (r) {
        return selectedKeys[r.id] === true;
    })
    readonly property real tableOffset: {
        if (!viewport)
            return 0;
        const moved = viewport.contentY;
        return mapToItem(viewport.contentItem, 0, 0).y;
    }
    readonly property int firstRow: viewport ? Math.max(0, Math.floor((viewport.contentY - tableOffset - 48) / 64) - 3) :
                                               0
    readonly property int lastRow: viewport ? Math.min(rows.length, Math.ceil((viewport.contentY + viewport.height - tableOffset
                                                                               - 48) / 64) + 3) : rows.length
    implicitHeight: 48 + (rows.length || 1) * 64
    height: implicitHeight
    function clear() {
        selectedKeys = ({});
    }
    function selectAll() {
        const keys = {};
        rows.forEach(function (r) {
            keys[r.id] = true;
        });
        selectedKeys = keys;
    }
    function toggle(row) {
        const keys = Object.assign({}, selectedKeys);
        if (keys[row.id])
            delete keys[row.id];
        else
            keys[row.id] = true;
        selectedKeys = keys;
        if (host.activeHistorySelection !== undefined)
            host.activeHistorySelection = table;
    }
    onRowsChanged: clear()
    property string amountKey: "displayAmount"
    property string currency: "RUB"
    readonly property var columns: [.16, .26, .38, .20]
    function colX(index) {
        let total = 0;
        for (let i = 0; i < index; ++i)
            total += columns[i];
        return Math.round(width * total);
    }
    Item {
        width: parent.width
        height: 48
        Rectangle {
            anchors.fill: parent
            color: "#e9e0ce"
        }
        Rectangle {
            width: parent.width
            height: 1
            color: "#031528"
        }
        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: "#031528"
        }
        Repeater {
            model: ["ДАТА", "КАТЕГОРИЯ", "ОПИСАНИЕ", "СУММА"]
            EditorialText {
                required property string modelData
                required property int index
                x: table.colX(index)
                width: Math.round(table.width * table.columns[index])
                height: 48
                text: modelData
                font.family: "Cousine"
                font.pixelSize: 12
                horizontalAlignment: index === 3 ? Text.AlignRight : Text.AlignLeft
                rightPadding: index < 3 ? 16 : 0
            }
        }
    }
    Repeater {
        model: table.rows.slice(table.firstRow, table.lastRow)
        delegate: Item {
            id: row
            required property int index
            required property var modelData
            y: 48 + (table.firstRow + index) * 64
            width: table.width
            height: 64
            Rectangle {
                anchors.fill: parent
                color: table.selectedKeys[row.modelData.id] ? "#09031528" : "transparent"
            }
            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: "#bbb5a8"
            }
            Repeater {
                model: [Qt.formatDate(new Date(row.modelData.date), "dd.MM.yyyy"), row.modelData.categoryName
                    || row.modelData.kind || "—", row.modelData.asset || table.host.transactionSummary(row.modelData),
                    table.host.money(row.modelData[table.amountKey] !== undefined ? row.modelData[table.amountKey] :
                                                                                    row.modelData.amount, table.currency,
                                     false)]
                EditorialText {
                    required property var modelData
                    required property int index
                    x: table.colX(index)
                    width: Math.round(table.width * table.columns[index])
                    height: 64
                    text: modelData
                    font.pixelSize: 14
                    rightPadding: index < 3 ? 16 : 0
                    horizontalAlignment: index === 3 ? Text.AlignRight : Text.AlignLeft
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function (event) {
                    if (event.button === Qt.LeftButton)
                        table.toggle(row.modelData);
                    else if (table.selectedRows.length) {
                        menu.x = table.mapFromItem(mouse, event.x, event.y).x;
                        menu.y = table.mapFromItem(mouse, event.x, event.y).y;
                        menu.open();
                    } else
                        table.host.openTransactionContextMenu(row.modelData, mouse, event.x, event.y);
                }
            }
        }
    }
    EditorialText {
        y: 48
        visible: table.rows.length === 0
        width: parent.width
        height: 64
        text: "Операций пока нет"
        color: "#59616a"
    }
    onVisibleChanged: if (!visible)
                          clear()
    Item {
        parent: table.Window.window ? table.Window.window.contentItem : null
        anchors.fill: parent
        z: 1000
        property bool middleScrollViewport: true
        visible: table.visible && table.selectedRows.length > 0 && (typeof table.host.modalDialogVisible !== "function" ||
                                                                    !table.host.modalDialogVisible())
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function (mouse) {
                if (!menu.visible) {
                    const point = table.mapFromItem(this, mouse.x, mouse.y);
                    if (point.x < 0 || point.x >= table.width || point.y < 0 || point.y >= table.height)
                        table.clear();
                }
                mouse.accepted = false;
            }
        }
    }
    EditorialMenu {
        id: menu
        EditorialMenuItem {
            text: "Выделить все"
            onTriggered: table.selectAll()
        }
        EditorialMenuItem {
            text: "Удалить выделенные"
            onTriggered: table.host.editorialDeleteHistory(table)
        }
    }
}
