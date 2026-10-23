import QtQuick
import QtQuick.Layouts

MobileSheet {
    id: sheet

    property string metric: ""
    property string displayValue: ""
    readonly property var entry: MobileMetricDefinitions.entries[metric] || ["Показатель", "Подробности приведены в пояснениях к расчёту.", "", ""]

    title: entry[0]

    function openFor(key, value) {
        metric = key;
        displayValue = value;
        open();
    }

    MobileText {
        font.family: MobileTheme.sans
        Layout.fillWidth: true
        visible: sheet.displayValue.length > 0
        text: "Сейчас: %1".arg(sheet.displayValue)
        wrapMode: Text.Wrap
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeBody
        font.weight: Font.DemiBold
    }
    MobileText {
        font.family: MobileTheme.sans
        Layout.fillWidth: true
        text: sheet.entry[1]
        wrapMode: Text.Wrap
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeBody
    }
    MobileText {
        font.family: MobileTheme.sans
        Layout.fillWidth: true
        visible: sheet.entry[2].length > 0
        text: "Расчёт: %1".arg(sheet.entry[2])
        wrapMode: Text.Wrap
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeBody
    }
    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        visible: sheet.entry[3].length > 0
        text: sheet.entry[3]
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }
    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        text: "Если показано «—», проверьте блок «Качество данных» и пояснения к расчёту."
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }
}
