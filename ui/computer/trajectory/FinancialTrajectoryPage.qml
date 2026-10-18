import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../dashboard"

EditorialPage {
    id: page
    required property var theme
    host: theme
    title: qsTr("Финансовая траектория.")
    readonly property var trajectory: controller.financialTrajectory
    property string scenarioName: "base"
    function money(value) {
        return theme.money(value, trajectory.currency, false);
    }
    function number(text) {
        var value = Number(String(text).replace(",", "."));
        return isFinite(value) ? value : 0;
    }
    function applySettings() {
        var result = controller.saveFinancialTrajectorySettings({
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
                                                                });
        errorText.text = result.ok ? "" : result.error;
    }
    function scenario(kind) {
        if (kind === "safe") {
            returnField.text = "2";
            incomeField.text = "-10";
            expenseField.text = "10";
        } else if (kind === "growth") {
            returnField.text = "8";
            incomeField.text = "5";
            expenseField.text = "-5";
        } else {
            returnField.text = "5";
            incomeField.text = "0";
            expenseField.text = "0";
        }
        applySettings();
    }

    EditorialMetrics {
        width: parent.width
        height: implicitHeight
        columns: page.host.width <= 850 ? 2 : 4
        metrics: [
            {
                label: qsTr("Текущий капитал"),
                value: page.money(trajectory.currentMinor)
            },
            {
                label: qsTr("Накопление в месяц"),
                value: page.money(trajectory.averageSavingMinor)
            },
            {
                label: qsTr("К концу прогноза"),
                value: trajectory.forecast.length ? page.money(trajectory.forecast[trajectory.forecast.length
                                                                                   - 1].valueMinor) : "—"
            },
            {
                label: qsTr("Доля накоплений"),
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
                title: qsTr("Финансовая траектория")
                note: qsTr("%1 МЕСЯЦЕВ").arg(trajectory.horizonMonths)
            }
            EditorialChart {
                objectName: "editorialTrajectoryChart"
                width: parent.width
                height: 320
                host: page.host
                currency: trajectory.currency
                series: [
                    {
                        label: qsTr("Прогноз"),
                        rows: trajectory.forecast.map(function (r) {
                            return {
                                date: r.date,
                                value: r.valueMinor
                            };
                        })
                    },
                    {
                        label: qsTr("С учётом инфляции"),
                        dashed: true,
                        rows: trajectory.forecast.map(function (r) {
                            return {
                                date: r.date,
                                value: r.realMinor
                            };
                        })
                    }
                ]
            }
            EditorialLegend {
                width: parent.width
                entries: [
                    {
                        label: qsTr("Прогноз")
                    },
                    {
                        label: qsTr("С учётом инфляции"),
                        dashed: true
                    }
                ]
            }
            EditorialText {
                width: parent.width
                height: implicitHeight
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                color: "#59616a"
                text: qsTr(
                          "Доходность применяется к текущей стоимости инвестиций; будущие накопления автоматически не считаются вложенными.")
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
                    title: qsTr("Параметры прогноза")
                }
                Row {
                    width: parent.width
                    height: 64
                    spacing: 8
                    Repeater {
                        model: [
                            {
                                key: "base",
                                title: qsTr("Базовый")
                            },
                            {
                                key: "safe",
                                title: qsTr("Осторожный")
                            },
                            {
                                key: "growth",
                                title: qsTr("Рискованный")
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
                        text: qsTr("Среднее за")
                        font.pixelSize: 14
                    }
                    EditorialChoice {
                        id: analysis
                        Layout.preferredWidth: 120
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            {
                                text: qsTr("3 месяца"),
                                value: 3
                            },
                            {
                                text: qsTr("6 месяцев"),
                                value: 6
                            },
                            {
                                text: qsTr("12 месяцев"),
                                value: 12
                            }
                        ]
                        Component.onCompleted: currentIndex = Math.max(0, [3, 6, 12].indexOf(trajectory.analysisMonths))
                    }
                }
                SettingRow {
                    EditorialText {
                        Layout.fillWidth: true
                        text: qsTr("Горизонт")
                        font.pixelSize: 14
                    }
                    EditorialChoice {
                        id: horizon
                        Layout.preferredWidth: 120
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            {
                                text: qsTr("6 месяцев"),
                                value: 6
                            },
                            {
                                text: qsTr("1 год"),
                                value: 12
                            },
                            {
                                text: qsTr("3 года"),
                                value: 36
                            },
                            {
                                text: qsTr("5 лет"),
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
                        text: qsTr("Доходность в год, %")
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
                        text: qsTr("Инфляция в год, %")
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
                        text: qsTr("Изменение доходов, %")
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
                        text: qsTr("Изменение расходов, %")
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
                        text: qsTr("Разовая покупка")
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
                        text: qsTr("Через, месяцев")
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
                EditorialText {
                    id: errorText
                    width: parent.width
                    height: text ? implicitHeight + 16 : 0
                    wrapMode: Text.WordWrap
                    color: "#b84932"
                    font.pixelSize: 14
                    text: trajectory.complete ? "" : qsTr("Часть котировок недоступна: расчёт по известным активам.")
                }
                EditorialAction {
                    width: parent.width
                    height: 64
                    text: qsTr("ПЕРЕСЧИТАТЬ И СОХРАНИТЬ")
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
