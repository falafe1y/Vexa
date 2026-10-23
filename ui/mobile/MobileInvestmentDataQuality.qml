import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: panel

    property var quality: ({})
    property bool detailsOpen: false
    property int severityIndex: 0
    property string query: ""

    readonly property var items: quality.items || []
    readonly property var filtered: {
        const needle = panel.query.trim().toLocaleLowerCase();
        const severity = panel.severityIndex === 1 ? "error" : panel.severityIndex === 2 ? "warning" : panel.severityIndex === 3 ? "info" : "";
        return panel.items.filter(function (row) {
            return (!severity || row.severity === severity) && (!needle || [row.label, row.account, row.asset, row.impact, row.action, row.dateFrom, row.dateTo, (row.dates || []).join(" ")].join(" ").toLocaleLowerCase().indexOf(needle) >= 0);
        });
    }

    function date(value) {
        return value ? value.substr(8, 2) + "." + value.substr(5, 2) + "." + value.substr(0, 4) : "";
    }

    function context(row) {
        const parts = [];
        if (row.account)
            parts.push(row.account);
        if (row.asset)
            parts.push(row.asset);
        if (row.dateFrom)
            parts.push(panel.date(row.dateFrom) + (row.dateTo && row.dateTo !== row.dateFrom ? " — " + panel.date(row.dateTo) : ""));
        if (row.count > 1)
            parts.push((row.code === "missing_days" ? "Дней без оценок: %1" : "Записей: %1").arg(row.count));
        return parts.join(" · ");
    }

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MobileText {
            font.family: MobileTheme.serif
            Layout.fillWidth: true
            text: "Качество данных"
            color: MobileTheme.accent
            font.pixelSize: MobileTheme.sizeHeading
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }
        MobileButton {
            visible: panel.items.length > 0
            implicitHeight: 40
            text: panel.detailsOpen ? "Скрыть проблемы" : "Показать проблемы (%1)".arg(panel.items.length)
            onClicked: panel.detailsOpen = !panel.detailsOpen
        }
    }

    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        text: "Проверено строк оценок: %1 · Препятствуют расчёту: %2 · Ограничивают разбор: %3 · Особенности: %4".arg(panel.quality.checkedRows || 0).arg(panel.quality.errors || 0).arg(panel.quality.warnings || 0).arg(panel.quality.notes || 0)
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }

    MobileText {
        font.family: MobileTheme.mono
        visible: panel.items.length === 0
        Layout.fillWidth: true
        text: "В проверенных оценках и операциях выбранного периода проблем не найдено. Это проверка записанных данных, а не полный аудит."
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }

    Flow {
        visible: panel.detailsOpen && panel.items.length > 0
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: ["Все проблемы", "Препятствуют расчёту", "Ограничивают разбор", "Особенности учёта"]

            delegate: MobileChip {
                required property string modelData
                required property int index
                text: modelData
                selected: panel.severityIndex === index
                onClicked: panel.severityIndex = index
            }
        }
    }

    MobileField {
        visible: panel.detailsOpen && panel.items.length > 0
        Layout.fillWidth: true
        placeholder: "Счёт, актив, проблема или дата"
        onTextChanged: panel.query = text
    }

    Repeater {
        model: panel.detailsOpen ? panel.filtered : []

        delegate: MobileCard {
            required property var modelData

            Layout.fillWidth: true
            gap: 8

            MobileText {
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                text: modelData.label
                wrapMode: Text.Wrap
                color: modelData.severity === "error" ? MobileTheme.red : MobileTheme.accent
                font.pixelSize: MobileTheme.sizeBody
                font.weight: Font.Bold
            }
            MobileText {
                font.family: MobileTheme.mono
                Layout.fillWidth: true
                visible: text.length > 0
                text: panel.context(modelData)
                wrapMode: Text.Wrap
                color: MobileTheme.muted
                font.pixelSize: MobileTheme.sizeCaption
            }
            MobileText {
                font.family: MobileTheme.sans
                Layout.fillWidth: true
                text: modelData.impact
                wrapMode: Text.Wrap
                color: MobileTheme.accent
                font.pixelSize: MobileTheme.sizeBody
            }
            MobileText {
                font.family: MobileTheme.mono
                Layout.fillWidth: true
                text: "Что проверить: %1".arg(modelData.action)
                wrapMode: Text.Wrap
                color: MobileTheme.muted
                font.pixelSize: MobileTheme.sizeCaption
            }
            MobileText {
                font.family: MobileTheme.mono
                Layout.fillWidth: true
                visible: modelData.code !== "missing_days" && (modelData.dates || []).length > 2
                text: "Даты записей: %1".arg((modelData.dates || []).map(panel.date).join(", "))
                wrapMode: Text.Wrap
                color: MobileTheme.muted
                font.pixelSize: MobileTheme.sizeCaption
            }
        }
    }

    MobileText {
        font.family: MobileTheme.mono
        visible: panel.detailsOpen && panel.items.length > 0 && panel.filtered.length === 0
        Layout.fillWidth: true
        text: "По выбранному фильтру проблем не найдено."
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }
}
