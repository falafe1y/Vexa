import QtQuick
import QtQuick.Layouts
import "../common"
import "../dashboard"

Column {
    id: panel
    required property var controller
    required property var host
    readonly property var items: controller.averageReturnItems || []
    readonly property var summary: controller.averageReturnSummary || ({})
    readonly property var excluded: summary.excluded || []
    readonly property bool merged: summary.merged !== false
    readonly property var accountGroups: {
        const groups = {};
        const accounts = controller.allAccounts || [];
        const positions = controller.investmentPositions || [];
        items.forEach(function (item) {
            let key = item.group, name = item.group === "crypto" ? qsTr("Криптовалюта") : qsTr("Инвестиции");
            if (item.id.indexOf("deposit:") === 0) {
                key = item.id.substr(8);
                name = item.title;
            } else if (item.id.indexOf("position:") === 0) {
                const position = positions.find(function (p) {
                    return p.id === item.id.substr(9);
                });
                if (position) {
                    key = position.accountId;
                    const account = accounts.find(function (a) {
                        return a.id === key;
                    });
                    if (account)
                        name = account.name;
                }
            } else if (item.id.indexOf("crypto:") === 0) {
                key = item.id.split(":")[1];
                name = item.title.split(" · ")[0];
            }
            if (!groups[key])
                groups[key] = {
                    id: key,
                    name: name,
                    items: []
                };
            groups[key].items.push(item);
        });
        return Object.keys(groups).map(function (key) {
            return groups[key];
        });
    }
    function percent(value) {
        return value === null || value === undefined ? "—" : Number(value).toLocaleString(Qt.locale("ru_RU"), "f", 1)
                                                       + " %";
    }
    function selected(id) {
        return excluded.indexOf(id) < 0;
    }
    function include(ids, checked) {
        const next = excluded.filter(function (id) {
            return ids.indexOf(id) < 0;
        });
        if (!checked)
            next.push.apply(next, ids);
        controller.setAverageReturnSelection(next, merged);
    }
    RowLayout {
        width: parent.width
        height: 64
        spacing: 24
        EditorialSection {
            Layout.fillWidth: true
            number: 3
            title: qsTr("Средняя годовая доходность")
        }
        EditorialCheck {
            objectName: "editorialReturnMerged"
            text: qsTr("Объединить криптовалюту и инвестиции")
            checked: panel.merged
            onToggled: panel.controller.setAverageReturnSelection(panel.excluded, checked)
        }
    }
    GridLayout {
        objectName: "editorialReturnFigures"
        width: parent.width
        columns: panel.merged ? 1 : 2
        columnSpacing: 0
        rowSpacing: 0
        Repeater {
            model: panel.summary.groups || []
            delegate: Item {
                id: figure
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: Math.max(312, figureBody.implicitHeight + 48)
                objectName: "editorialReturnFigure"
                Rectangle {
                    visible: !panel.merged && figure.index === 0
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: "#bbb5a8"
                }
                GridLayout {
                    id: figureBody
                    width: panel.merged ? Math.min(parent.width, 848) : parent.width - 24
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    columns: !panel.merged && panel.host.width <= 1150 ? 1 : 2
                    columnSpacing: panel.merged ? 48 : 24
                    rowSpacing: 16
                    EditorialDonut {
                        objectName: "editorialReturnDonut"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: panel.merged ? 280 : panel.host.width <= 1500 ? 176 : 224
                        Layout.preferredHeight: Layout.preferredWidth
                        slices: figure.modelData.slices || []
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        spacing: 8
                        EditorialText {
                            Layout.fillWidth: true
                            text: figure.modelData.title
                            font.family: "PT Serif"
                            font.pixelSize: 24
                        }
                        EditorialText {
                            Layout.fillWidth: true
                            text: panel.percent(figure.modelData.annualPercent)
                            font.family: "PT Serif"
                            font.pixelSize: panel.host.width <= 1150 ? 36 : 48
                        }
                        EditorialText {
                            Layout.fillWidth: true
                            text: panel.host.money(figure.modelData.valueMinor, panel.controller.appCurrency, false)
                            font.family: "Cousine"
                            font.pixelSize: 12
                            color: "#59616a"
                        }
                        EditorialText {
                            Layout.fillWidth: true
                            text: qsTr("УЧТЕНО %1 ИЗ %2").arg(figure.modelData.counted).arg(figure.modelData.shown)
                            font.family: "Cousine"
                            font.pixelSize: 12
                            color: "#59616a"
                        }
                        Repeater {
                            model: figure.modelData.slices || []
                            RowLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 8
                                    height: 8
                                    color: ["#031528", "#be7b56", "#b8ae99", "#738073", "#6b7fa3"][index % 5]
                                }
                                EditorialText {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.pixelSize: 14
                                    color: "#59616a"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Rectangle {
        width: parent.width
        height: 1
        color: "#031528"
    }
    EditorialText {
        width: parent.width
        height: 64
        text: qsTr("Учитываемые счета и инструменты")
        font.family: "PT Serif"
        font.pixelSize: 24
    }
    GridLayout {
        width: parent.width
        columns: panel.host.width <= 1150 ? 1 : 3
        columnSpacing: 24
        rowSpacing: 24
        Repeater {
            model: panel.accountGroups
            ColumnLayout {
                id: accountGroup
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 0
                EditorialCheck {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 64
                    objectName: "editorialReturnAccount"
                    text: accountGroup.modelData.name
                    tristate: true
                    checkState: {
                        const n = accountGroup.modelData.items.filter(function (i) {
                            return panel.selected(i.id);
                        }).length;
                        return n === 0 ? Qt.Unchecked : n === accountGroup.modelData.items.length ? Qt.Checked :
                                                                                                    Qt.PartiallyChecked;
                    }
                    nextCheckState: function () {
                        return checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked;
                    }
                    onClicked: panel.include(accountGroup.modelData.items.map(function (i) {
                        return i.id;
                    }), checkState === Qt.Checked)
                }
                Repeater {
                    model: accountGroup.modelData.items
                    Item {
                        id: instrument
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        EditorialCheck {
                            objectName: "editorialReturnInstrument"
                            width: Math.max(0, parent.width - value.width - 16)
                            height: parent.height
                            text: instrument.modelData.title
                            checked: panel.selected(instrument.modelData.id)
                            onToggled: panel.include([instrument.modelData.id], checked)
                        }
                        Column {
                            id: value
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            EditorialText {
                                text: panel.host.money(instrument.modelData.valueMinor, panel.controller.appCurrency,
                                                       false)
                                font.family: "Cousine"
                                font.pixelSize: 12
                            }
                            EditorialText {
                                text: panel.percent(instrument.modelData.annualPercent)
                                font.family: "Cousine"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                        Rectangle {
                            y: parent.height - 1
                            width: parent.width
                            height: 1
                            color: "#bbb5a8"
                        }
                    }
                }
            }
        }
    }
    EditorialText {
        width: parent.width
        height: implicitHeight
        text: qsTr(
                  "Учитываются инструменты с историей от 30 дней. Кошельки и стейблкоины в среднюю доходность не входят.")
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        color: "#59616a"
        topPadding: 16
        bottomPadding: 16
    }
    Rectangle {
        width: parent.width
        height: 1
        color: "#031528"
    }
}
