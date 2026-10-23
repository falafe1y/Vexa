import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

EditorialColumnLayout {
    id: panel
    property var payments: ({})
    property string currency: "RUB"
    property color ink: "#031528"
    property color muted: (Appearance.desktop ? "#59616a" : "#687483")
    property color line: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color positive: "#3F735F"
    property color negative: (Appearance.desktop ? "#b84932" : "#B94F48")
    property bool eventsOpen: false
    readonly property var months: payments.months || []
    readonly property real maximumMonth: {
        var n = 0
        for (var i = 0; i < months.length; ++i) if (available(months[i].netMinor)) n = Math.max(n, Math.abs(Number(months[i].netMinor)))
        return Math.max(n, 1)
    }
    function available(n) { return n !== undefined && n !== null && isFinite(Number(n)) }
    function amount(n) { return available(n) ? Number(n / 100).toLocaleString(Qt.locale(), 'f', 2) + " " + currency : "—" }
    function date(s) { return s ? s.substr(8, 2) + "." + s.substr(5, 2) + "." + s.substr(0, 4) : "—" }
    spacing: 12
    EditorialLabel { text: "Аналитика выплат"; color: panel.ink; font.pixelSize: 17; font.bold: true }
    EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: panel.muted; text: "Дивиденды, купоны и проценты по вкладам за выбранный период. Каждая выплата переведена в валюту отчёта по историческому курсу на её дату." }
    GridLayout {
        Layout.fillWidth: true
        columns: panel.width < 750 ? 2 : 4
        columnSpacing: Appearance.desktop ? 12 : 10; rowSpacing: Appearance.desktop ? 12 : 10
        Repeater {
            model: [{label: "Получено", value: panel.amount(panel.payments.netMinor)},
                {label: "До расходов", value: panel.amount(panel.payments.grossMinor)},
                {label: "Комиссии выплат", value: panel.amount(panel.payments.feesMinor)},
                {label: "Удержания выплат", value: panel.amount(panel.payments.taxMinor)}]
            delegate: Rectangle {
                required property var modelData
                required property int index
                Layout.fillWidth: true; implicitHeight: 104; radius: Appearance.desktop ? 0 : 8; color: "transparent"; border.color: panel.line
                EditorialColumnLayout {
                    anchors.fill: parent; anchors.margins: Appearance.desktop ? 12 : 10
                    EditorialRowLayout {
                        Layout.fillWidth: true
                        EditorialLabel { Layout.fillWidth: true; text: modelData.label; color: panel.muted }
                        InvestmentMetricHelp { metric: ["payments_net","payments_gross","payments_fees","payments_tax"][index]; displayValue: modelData.value; ink: panel.ink; muted: panel.muted }
                    }
                    EditorialLabel { Layout.fillWidth: true; text: modelData.value; color: panel.ink; font.bold: true; font.pixelSize: 18; elide: Text.ElideRight }
                }
            }
        }
    }
    EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: panel.muted; text: "Записей: %1".arg(panel.payments.count || 0) + (panel.available(panel.payments.netMinor) ? "" : " · Известная часть полученного: %1".arg(panel.amount(panel.payments.knownNetMinor))) }
    EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: panel.muted; font.pixelSize: 12; text: "Если расходы не указаны отдельно, сумма до расходов и соответствующие итоги не вычисляются. Проценты по вкладам записываются чистой суммой: их комиссии и удержания неизвестны. Комиссии покупки и продажи относятся к результату позиций." }
    Repeater {
        model: panel.payments.kinds || []
        delegate: EditorialRowLayout {
            required property var modelData
            Layout.fillWidth: true
            EditorialLabel { Layout.fillWidth: true; text: modelData.label + " · Записей: %1".arg(modelData.count); color: panel.ink }
            EditorialLabel { text: panel.amount(modelData.netMinor); color: panel.positive; font.bold: true }
        }
    }
    EditorialRowLayout {
        visible: panel.months.length > 0; Layout.fillWidth: true
        EditorialLabel { text: "Получено по месяцам"; color: panel.ink; font.bold: true; Layout.fillWidth: true }
        InvestmentMetricHelp { metric: "payments_months"; ink: panel.ink; muted: panel.muted }
    }
    Repeater {
        model: panel.months
        delegate: EditorialRowLayout {
            required property var modelData
            Layout.fillWidth: true
            EditorialLabel { Layout.preferredWidth: Appearance.desktop ? 68 : 65; text: modelData.label; color: panel.muted }
            Item {
                Layout.fillWidth: true; implicitHeight: 16
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: panel.available(modelData.netMinor) ? Math.abs(Number(modelData.netMinor)) / panel.maximumMonth * parent.width : 0; height: 10; radius: 3; color: modelData.netMinor < 0 ? panel.negative : panel.positive }
            }
            EditorialLabel { text: panel.amount(modelData.netMinor); color: panel.ink; Layout.preferredWidth: Appearance.desktop ? 156 : 155; horizontalAlignment: Text.AlignRight }
        }
    }
    EditorialLabel { visible: (panel.payments.assets || []).length > 0; text: "Источники выплат"; color: panel.ink; font.bold: true }
    Repeater {
        model: panel.payments.assets || []
        delegate: EditorialRowLayout {
            required property var modelData
            Layout.fillWidth: true
            EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: modelData.label; color: panel.ink }
            EditorialLabel { text: panel.amount(modelData.netMinor); color: panel.ink }
        }
    }
    EditorialLabel { visible: !(panel.payments.count > 0); text: "За выбранный период выплаты не записаны."; color: panel.muted }
    StyledButton { visible: panel.payments.count > 0; text: panel.eventsOpen ? "Скрыть выплаты" : "Показать выплаты"; onClicked: panel.eventsOpen = !panel.eventsOpen }
    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Math.min(330, count * 94) : 0
        visible: panel.eventsOpen
        clip: true
        model: panel.payments.events || []
        ScrollBar.vertical: ScrollBar {}
        delegate: EditorialColumnLayout {
            required property var modelData
            width: ListView.view.width - 16
            height: 94
            spacing: Appearance.desktop ? 4 : 2
            EditorialRowLayout {
                Layout.fillWidth: true
                EditorialLabel { Layout.fillWidth: true; elide: Text.ElideRight; text: panel.date(modelData.date) + " · " + modelData.kind + " · " + modelData.asset; color: panel.ink }
                EditorialLabel { text: panel.amount(modelData.netMinor); color: panel.ink; font.bold: true }
            }
            EditorialLabel { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.account + " · " + Number(modelData.nativeNetMinor / 100).toLocaleString(Qt.locale(), 'f', 2) + " " + modelData.currency; color: panel.muted; font.pixelSize: 12 }
            EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "До расходов: %1 · Комиссии: %2 · Удержания: %3".arg(panel.amount(modelData.grossMinor)).arg(panel.amount(modelData.feesMinor)).arg(panel.amount(modelData.taxMinor)); color: panel.muted; font.pixelSize: 12 }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: panel.line }
        }
    }
}
