import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../dashboard"

EditorialPage {
    id: page
    required property var theme
    host: theme
    title: "Финансовая траектория."
    readonly property var trajectory: controller.financialTrajectory
    property string scenarioName: "base"
    // The sources the user ticked for the calculation; saved with the next recalculation
    property var sourceSelection: trajectory.sourceIds || []
    function toggleSource(id, on) {
        const list = sourceSelection.filter(function (item) { return item !== id; });
        if (on)
            list.push(id);
        sourceSelection = list;
    }
    function money(value) {
        return theme.money(value, trajectory.currency, false);
    }
    function number(text) {
        var value = Number(String(text).replace(",", "."));
        return isFinite(value) ? value : 0;
    }
    function applySettings() {
        var result = controller.saveFinancialTrajectorySettings(Object.assign({
                                                                    analysisMonths: Number(analysis.currentValue),
                                                                    horizonMonths: Number(horizon.currentValue),
                                                                    annualReturnPercent: number(returnField.text),
                                                                    annualInflationPercent: number(inflationField.text),
                                                                    incomeChangePercent: number(incomeField.text),
                                                                    expenseChangePercent: number(expenseField.text),
                                                                    purchaseMinor: Math.max(0, Math.round(number(
                                                                                                              purchaseField.text)
                                                                                                          * 100)),
                                                                    purchaseMonth: purchaseEnabled.checked ? Math.min(
                                                                                                                 Number(purchaseMonth.currentValue),
                                                                                                                 Number(horizon.currentValue)) :
                                                                                                             0
                                                                }, {allSources: allSourcesCheck.checked, sourceIds: page.sourceSelection}));
        errorText.text = result.ok ? "" : result.error;
    }
    // A mode sets the return as the typed inflation plus a spread, and the income and expense changes
    function scenario(kind) {
        const presets = {
            safe: { spread: 0, income: 0, expense: 0 },
            growth: { spread: 8, income: 30, expense: 15 },
            base: { spread: 3, income: 10, expense: 5 }
        };
        const preset = presets[kind] || presets.base;
        returnField.text = String(number(inflationField.text) + preset.spread);
        incomeField.text = String(preset.income);
        expenseField.text = String(preset.expense);
        applySettings();
    }

    EditorialMetrics {
        width: parent.width
        height: implicitHeight
        columns: page.host.width <= 850 ? 2 : 4
        metrics: [
            {
                label: "Текущий капитал",
                value: page.money(trajectory.currentMinor)
            },
            {
                label: "Накопление в месяц",
                value: page.money(trajectory.averageSavingMinor)
            },
            {
                label: "К концу прогноза",
                value: trajectory.forecast.length ? page.money(trajectory.forecast[trajectory.forecast.length
                                                                                   - 1].valueMinor) : "—"
            },
            {
                label: "Доля накоплений",
                value: Number(trajectory.savingRate).toFixed(1).replace(".", ",") + " %"
            }
        ]
    }
    RowLayout {
        width: parent.width
        spacing: 0
        Column {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignTop
            Layout.rightMargin: 24
            spacing: 16
            Item {
                width: 1
                height: 8
            }
            EditorialSection {
                width: parent.width
                number: 1
                title: "Финансовая траектория"
                note: "%1 МЕСЯЦЕВ".arg(trajectory.horizonMonths)
            }
            EditorialChart {
                objectName: "editorialTrajectoryChart"
                width: parent.width
                height: 320
                host: page.host
                currency: trajectory.currency
                series: [
                    {
                        label: "Прогноз",
                        rows: trajectory.forecast.map(function (r) {
                            return {
                                date: r.date,
                                value: r.valueMinor
                            };
                        })
                    },
                    {
                        label: "С учётом инфляции",
                        dashed: true,
                        rows: trajectory.forecast.map(function (r) {
                            return {
                                date: r.date,
                                value: r.realMinor
                            };
                        })
                    },
                    {
                        label: "Со сложным процентом",
                        dotted: true,
                        rows: trajectory.forecast.map(function (r) {
                            return {
                                date: r.date,
                                value: r.compoundMinor
                            };
                        })
                    }
                ]
            }
            EditorialLegend {
                width: parent.width
                entries: [
                    {
                        label: "Прогноз"
                    },
                    {
                        label: "С учётом инфляции",
                        dashed: true
                    },
                    {
                        label: "Со сложным процентом",
                        dotted: true
                    }
                ]
            }
            EditorialText {
                width: parent.width
                height: implicitHeight
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                color: "#59616a"
                text: "Доходность применяется к текущей стоимости инвестиций; будущие накопления автоматически не считаются вложенными. Линия «Со сложным процентом» вкладывает накопления каждый месяц и тоже приносит по ним доходность."
            }
        }
        Item {
            Layout.preferredWidth: page.host.width <= 1150 ? 280 : 320
            Layout.preferredHeight: settings.height + 56
            Rectangle {
                width: 1
                height: parent.height
                color: "#031528"
            }
            Column {
                id: settings
                x: 24
                y: 24
                width: parent.width - 24
                spacing: 0
                EditorialSection {
                    width: parent.width
                    number: 2
                    title: "Параметры прогноза"
                }
                Row {
                    width: parent.width
                    height: 64
                    spacing: 8
                    Repeater {
                        model: [
                            {
                                key: "base",
                                title: "Базовый"
                            },
                            {
                                key: "safe",
                                title: "Осторожный"
                            },
                            {
                                key: "growth",
                                title: "Рискованный"
                            }
                        ]
                        EditorialAction {
                            required property var modelData
                            width: (settings.width - 16) / 3
                            height: 48
                            arrow: false
                            mono: false
                            textSize: 12
                            text: modelData.title
                            underline: page.scenarioName === modelData.key
                            onClicked: {
                                page.scenarioName = modelData.key;
                                page.scenario(modelData.key);
                            }
                        }
                    }
                }
                SettingRow {
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Среднее за"
                        font.pixelSize: 14
                    }
                    EditorialChoice {
                        id: analysis
                        Layout.preferredWidth: 120
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            {
                                text: "3 месяца",
                                value: 3
                            },
                            {
                                text: "6 месяцев",
                                value: 6
                            },
                            {
                                text: "12 месяцев",
                                value: 12
                            }
                        ]
                        Component.onCompleted: currentIndex = Math.max(0, [3, 6, 12].indexOf(trajectory.analysisMonths))
                    }
                }
                SettingRow {
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Горизонт"
                        font.pixelSize: 14
                    }
                    EditorialChoice {
                        id: horizon
                        Layout.preferredWidth: 120
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            {
                                text: "6 месяцев",
                                value: 6
                            },
                            {
                                text: "1 год",
                                value: 12
                            },
                            {
                                text: "3 года",
                                value: 36
                            },
                            {
                                text: "5 лет",
                                value: 60
                            }
                        ]
                        Component.onCompleted: currentIndex = Math.max(0, [6, 12, 36, 60].indexOf(
                                                                           trajectory.horizonMonths))
                    }
                }
                SettingRow {
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Доходность в год, %"
                        font.pixelSize: 14
                    }
                    EditorialField {
                        id: returnField
                        Layout.preferredWidth: 96
                        text: trajectory.annualReturnPercent
                        horizontalAlignment: Text.AlignRight
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }
                SettingRow {
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Инфляция в год, %"
                        font.pixelSize: 14
                    }
                    EditorialField {
                        id: inflationField
                        Layout.preferredWidth: 96
                        text: trajectory.annualInflationPercent
                        horizontalAlignment: Text.AlignRight
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }
                SettingRow {
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Изменение доходов, %"
                        font.pixelSize: 14
                    }
                    EditorialField {
                        id: incomeField
                        Layout.preferredWidth: 96
                        text: trajectory.incomeChangePercent
                        horizontalAlignment: Text.AlignRight
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }
                SettingRow {
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Изменение расходов, %"
                        font.pixelSize: 14
                    }
                    EditorialField {
                        id: expenseField
                        Layout.preferredWidth: 96
                        text: trajectory.expenseChangePercent
                        horizontalAlignment: Text.AlignRight
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                }
                SettingRow {
                    EditorialCheck {
                        id: purchaseEnabled
                        checked: trajectory.purchaseMonth > 0
                    }
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Разовая покупка"
                        font.pixelSize: 14
                    }
                    EditorialField {
                        id: purchaseField
                        enabled: purchaseEnabled.checked
                        Layout.preferredWidth: 96
                        text: (trajectory.purchaseMinor / 100).toFixed(2)
                        horizontalAlignment: Text.AlignRight
                    }
                }
                SettingRow {
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Через, месяцев"
                        font.pixelSize: 14
                    }
                    EditorialChoice {
                        id: purchaseMonth
                        enabled: purchaseEnabled.checked
                        Layout.preferredWidth: 120
                        textRole: "text"
                        valueRole: "value"
                        model: Array.from({
                                              length: 60
                                          }, function (_, i) {
                                              return {
                                                  text: String(i + 1),
                                                  value: i + 1
                                              };
                                          })
                        Component.onCompleted: currentIndex = Math.max(0, Math.min(59, trajectory.purchaseMonth - 1))
                    }
                }
                SettingRow {
                    EditorialCheck {
                        id: allSourcesCheck
                        checked: trajectory.allSources
                    }
                    EditorialText {
                        Layout.fillWidth: true
                        text: "Все счета и кошельки"
                        font.pixelSize: 14
                    }
                }
                Repeater {
                    model: controller.goalSources
                    SettingRow {
                        required property var modelData
                        EditorialCheck {
                            enabled: !allSourcesCheck.checked
                            checked: allSourcesCheck.checked || page.sourceSelection.indexOf(modelData.id) >= 0
                            onToggled: page.toggleSource(modelData.id, checked)
                        }
                        EditorialText {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                }
                EditorialText {
                    id: errorText
                    width: parent.width
                    height: text ? implicitHeight + 16 : 0
                    wrapMode: Text.WordWrap
                    color: "#b84932"
                    font.pixelSize: 14
                    text: trajectory.complete ? "" : "Часть котировок недоступна: расчёт по известным активам."
                }
                EditorialAction {
                    width: parent.width
                    height: 64
                    text: "ПЕРЕСЧИТАТЬ И СОХРАНИТЬ"
                    onClicked: {
                        page.scenarioName = "custom";
                        page.applySettings();
                    }
                }
            }
        }
    }
    component SettingRow: Item {
        default property alias fields: row.data
        width: parent.width
        height: 64
        RowLayout {
            id: row
            anchors.fill: parent
            spacing: 16
        }
        Rectangle {
            y: 63
            width: parent.width
            height: 1
            color: "#bbb5a8"
        }
    }
    Rectangle {
        width: parent.width
        height: 1
        color: "#031528"
    }
}
