import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: panel

    property var payments: ({})
    property string currency: "RUB"
    property bool eventsOpen: false

    readonly property var months: payments.months || []
    readonly property real maximumMonth: {
        let maximum = 0;
        for (let i = 0; i < months.length; ++i)
            if (available(months[i].netMinor))
                maximum = Math.max(maximum, Math.abs(Number(months[i].netMinor)));
        return Math.max(maximum, 1);
    }

    function available(value) {
        return value !== undefined && value !== null && isFinite(Number(value));
    }
    function amount(value) {
        return available(value) ? MobileFormat.money(value, panel.currency, false) : "—";
    }
    function date(value) {
        return value ? value.substr(8, 2) + "." + value.substr(5, 2) + "." + value.substr(0, 4) : "—";
    }

    spacing: 12

    MobileText {
        font.family: MobileTheme.serif
        Layout.fillWidth: true
        text: "Аналитика выплат"
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeHeading
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
    }
    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        text: "Дивиденды, купоны и проценты по вкладам за выбранный период. Каждая выплата переведена в валюту отчёта по историческому курсу на её дату."
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 12
        rowSpacing: 12

        Repeater {
            model: [
                {
                    label: "Получено",
                    value: panel.amount(panel.payments.netMinor),
                    metric: "payments_net"
                },
                {
                    label: "До расходов",
                    value: panel.amount(panel.payments.grossMinor),
                    metric: "payments_gross"
                },
                {
                    label: "Комиссии выплат",
                    value: panel.amount(panel.payments.feesMinor),
                    metric: "payments_fees"
                },
                {
                    label: "Удержания выплат",
                    value: panel.amount(panel.payments.taxMinor),
                    metric: "payments_tax"
                }
            ]

            delegate: MobileCard {
                required property var modelData

                Layout.fillWidth: true
                cardPadding: 12
                gap: 8

                RowLayout {
                    Layout.fillWidth: true
                    MobileText {
                        font.family: MobileTheme.mono
                        Layout.fillWidth: true
                        text: modelData.label
                        color: MobileTheme.muted
                        font.pixelSize: MobileTheme.sizeCaption
                        wrapMode: Text.Wrap
                    }
                    MobileInfoButton {
                        metric: modelData.metric
                        displayValue: modelData.value
                    }
                }
                MobileText {
                    font.family: MobileTheme.serif
                    Layout.fillWidth: true
                    text: modelData.value
                    color: MobileTheme.accent
                    font.pixelSize: MobileTheme.sizeHeading
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }
        }
    }

    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        text: "Записей: %1".arg(panel.payments.count || 0) + (panel.available(panel.payments.netMinor) ? "" : " · Известная часть полученного: %1".arg(panel.amount(panel.payments.knownNetMinor)))
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }

    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        text: "Если расходы не указаны отдельно, сумма до расходов и соответствующие итоги не вычисляются. Проценты по вкладам записываются чистой суммой: их комиссии и удержания неизвестны. Комиссии покупки и продажи относятся к результату позиций."
        wrapMode: Text.Wrap
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }

    Repeater {
        model: panel.payments.kinds || []

        delegate: RowLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            MobileText {
                font.family: MobileTheme.mono
                Layout.fillWidth: true
                text: modelData.label + " · Записей: %1".arg(modelData.count)
                wrapMode: Text.Wrap
                color: MobileTheme.accent
                font.pixelSize: MobileTheme.sizeCaption
            }
            MobileText {
                font.family: MobileTheme.mono
                text: panel.amount(modelData.netMinor)
                color: MobileTheme.income
                font.pixelSize: MobileTheme.sizeCaption
                font.weight: Font.Bold
            }
        }
    }

    RowLayout {
        visible: panel.months.length > 0
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 8

        MobileText {
            font.family: MobileTheme.sans
            Layout.fillWidth: true
            text: "Получено по месяцам"
            color: MobileTheme.accent
            font.pixelSize: MobileTheme.sizeBody
            font.weight: Font.DemiBold
        }
        MobileInfoButton {
            metric: "payments_months"
        }
    }

    Repeater {
        model: panel.months

        delegate: RowLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            MobileText {
                font.family: MobileTheme.mono
                Layout.preferredWidth: 65
                text: modelData.label
                color: MobileTheme.muted
                font.pixelSize: MobileTheme.sizeCaption
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: 16

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: panel.available(modelData.netMinor) ? Math.abs(Number(modelData.netMinor)) / panel.maximumMonth * parent.width : 0
                    height: 10
                    radius: 3
                    color: modelData.netMinor < 0 ? MobileTheme.red : MobileTheme.income
                }
            }
            MobileText {
                font.family: MobileTheme.mono
                Layout.preferredWidth: 110
                horizontalAlignment: Text.AlignRight
                text: panel.amount(modelData.netMinor)
                color: MobileTheme.accent
                font.pixelSize: MobileTheme.sizeCaption
            }
        }
    }

    MobileText {
        font.family: MobileTheme.sans
        visible: (panel.payments.assets || []).length > 0
        Layout.topMargin: 6
        text: "Источники выплат"
        color: MobileTheme.accent
        font.pixelSize: MobileTheme.sizeBody
        font.weight: Font.DemiBold
    }
    Repeater {
        model: panel.payments.assets || []

        delegate: RowLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            MobileText {
                font.family: MobileTheme.mono
                Layout.fillWidth: true
                text: modelData.label
                wrapMode: Text.Wrap
                color: MobileTheme.accent
                font.pixelSize: MobileTheme.sizeCaption
            }
            MobileText {
                font.family: MobileTheme.mono
                text: panel.amount(modelData.netMinor)
                color: MobileTheme.accent
                font.pixelSize: MobileTheme.sizeCaption
            }
        }
    }

    MobileText {
        font.family: MobileTheme.mono
        visible: !(panel.payments.count > 0)
        Layout.fillWidth: true
        text: "За выбранный период выплаты не записаны."
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
    }

    MobileButton {
        visible: panel.payments.count > 0
        Layout.fillWidth: true
        text: panel.eventsOpen ? "Скрыть выплаты" : "Показать выплаты"
        onClicked: panel.eventsOpen = !panel.eventsOpen
    }

    Repeater {
        model: panel.eventsOpen ? (panel.payments.events || []) : []

        delegate: MobileCard {
            required property var modelData

            Layout.fillWidth: true
            cardPadding: 12
            gap: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: panel.date(modelData.date) + " · " + modelData.kind + " · " + modelData.asset
                    color: MobileTheme.accent
                    font.pixelSize: MobileTheme.sizeCaption
                    font.weight: Font.DemiBold
                }
                MobileText {
                    font.family: MobileTheme.mono
                    text: panel.amount(modelData.netMinor)
                    color: MobileTheme.accent
                    font.pixelSize: MobileTheme.sizeCaption
                    font.weight: Font.Bold
                }
            }
            MobileText {
                font.family: MobileTheme.mono
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: modelData.account + " · " + MobileFormat.money(modelData.nativeNetMinor, modelData.currency, false)
                color: MobileTheme.muted
                font.pixelSize: MobileTheme.sizeCaption
            }
            MobileText {
                font.family: MobileTheme.mono
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "До расходов: %1 · Комиссии: %2 · Удержания: %3".arg(panel.amount(modelData.grossMinor)).arg(panel.amount(modelData.feesMinor)).arg(panel.amount(modelData.taxMinor))
                color: MobileTheme.muted
                font.pixelSize: MobileTheme.sizeCaption
            }
        }
    }
}
