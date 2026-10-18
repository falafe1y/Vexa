import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

EditorialColumnLayout {
    id: panel
    property var quality: ({})
    property color ink: "#031528"
    property color muted: (Appearance.desktop ? "#59616a" : "#687483")
    property color line: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color negative: (Appearance.desktop ? "#b84932" : "#B94F48")
    property bool detailsOpen: false
    readonly property var items: quality.items || []
    readonly property var filtered: {
        var needle = query.text.trim().toLocaleLowerCase()
        return items.filter(function(row) {
            var severity = severityFilter.currentIndex === 1 ? "error" : severityFilter.currentIndex === 2 ? "warning" : severityFilter.currentIndex === 3 ? "info" : ""
            return (!severity || row.severity === severity) && (!needle || [row.label,row.account,row.asset,row.impact,row.action,row.dateFrom,row.dateTo,(row.dates || []).join(" ")].join(" ").toLocaleLowerCase().indexOf(needle) >= 0)
        })
    }
    function date(s) { return s ? s.substr(8,2) + "." + s.substr(5,2) + "." + s.substr(0,4) : "" }
    function context(row) {
        var parts = []
        if (row.account) parts.push(row.account)
        if (row.asset) parts.push(row.asset)
        if (row.dateFrom) parts.push(date(row.dateFrom) + (row.dateTo && row.dateTo !== row.dateFrom ? " — " + date(row.dateTo) : ""))
        if (row.count > 1) parts.push((row.code === "missing_days" ? qsTr("Дней без оценок: %1") : qsTr("Записей: %1")).arg(row.count))
        return parts.join(" · ")
    }
    spacing: 12
    EditorialRowLayout {
        Layout.fillWidth: true
        EditorialLabel { text: qsTr("Качество данных"); color: panel.ink; font.pixelSize: 17; font.bold: true; Layout.fillWidth: true }
        StyledButton { visible: panel.items.length > 0; text: panel.detailsOpen ? qsTr("Скрыть проблемы") : qsTr("Показать проблемы (%1)").arg(panel.items.length); onClicked: panel.detailsOpen = !panel.detailsOpen }
    }
    EditorialLabel {
        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: panel.muted
        text: qsTr("Проверено строк оценок: %1 · Препятствуют расчёту: %2 · Ограничивают разбор: %3 · Особенности: %4")
            .arg(panel.quality.checkedRows || 0).arg(panel.quality.errors || 0).arg(panel.quality.warnings || 0).arg(panel.quality.notes || 0)
    }
    EditorialLabel { visible: panel.items.length === 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: panel.muted; text: qsTr("В проверенных оценках и операциях выбранного периода проблем не найдено. Это проверка записанных данных, а не подтверждение их биржевым источником.") }
    EditorialRowLayout {
        visible: panel.detailsOpen && panel.items.length > 0
        Layout.fillWidth: true
        StyledComboBox { id: severityFilter; objectName: "qualitySeverity"; Layout.preferredWidth: Appearance.desktop ? 212 : 210; model: [qsTr("Все проблемы"), qsTr("Препятствуют расчёту"), qsTr("Ограничивают разбор"), qsTr("Особенности учёта")] }
        TextField { id: query; objectName: "qualitySearch"; Layout.fillWidth: true; placeholderText: qsTr("Счёт, актив, проблема или дата"); selectByMouse: true }
    }
    ListView {
        id: list
        visible: panel.detailsOpen && panel.items.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Math.min(contentHeight, 560) : 0
        clip: true; spacing: 12
        model: panel.filtered
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            required property var modelData
            width: list.width - 16
            height: details.implicitHeight + 24
            color: "transparent"; radius: Appearance.desktop ? 0 : 8; border.color: panel.line
            EditorialColumnLayout {
                id: details
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
                spacing: 8
                EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: modelData.label; color: modelData.severity === "error" ? panel.negative : panel.ink; font.bold: true }
                EditorialLabel { visible: text.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: panel.context(modelData); color: panel.muted; font.pixelSize: 12 }
                EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: modelData.impact; color: panel.ink }
                EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr("Что проверить: %1").arg(modelData.action); color: panel.muted }
                EditorialLabel {
                    visible: modelData.code !== "missing_days" && (modelData.dates || []).length > 2
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: panel.muted; font.pixelSize: 12
                    text: qsTr("Даты записей: %1").arg((modelData.dates || []).map(panel.date).join(", "))
                }
            }
        }
    }
    EditorialLabel { visible: panel.detailsOpen && panel.items.length > 0 && panel.filtered.length === 0; color: panel.muted; text: qsTr("По выбранному фильтру проблем не найдено.") }
}
