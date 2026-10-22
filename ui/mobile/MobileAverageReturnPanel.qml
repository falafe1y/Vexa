import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: panel
    readonly property var items: financeController.averageReturnItems || []
    readonly property var summary: financeController.averageReturnSummary || ({})
    readonly property var excluded: summary.excluded || []
    readonly property var groups: summary.groups || []
    readonly property bool merged: summary.merged !== false
    spacing: 20
    function percent(value) {
        return value === null || value === undefined ? "—" : Number(value).toLocaleString(MobileFormat.locale(), "f", 1) + " %";
    }
    function setIncluded(id, included) {
        const next = excluded.filter(function (value) {
            return value !== id;
        });
        if (!included)
            next.push(id);
        financeController.setAverageReturnSelection(next, merged);
    }
    Repeater {
        model: panel.groups
        delegate: ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            spacing: 12
            MobileText {
                Layout.fillWidth: true
                text: group.modelData.title
                font.pixelSize: 24
                font.family: MobileTheme.serif
                wrapMode: Text.Wrap
            }
            Canvas {
                id: pie
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(panel.width, panel.merged ? 240 : 184)
                Layout.preferredHeight: Layout.preferredWidth
                readonly property var slices: group.modelData.slices || []
                onSlicesChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    let start = -Math.PI / 2;
                    if (!slices.length) {
                        ctx.strokeStyle = MobileTheme.line;
                        ctx.lineWidth = 28;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2 - 16, 0, Math.PI * 2);
                        ctx.stroke();
                    }
                    for (let i = 0; i < slices.length; ++i) {
                        const end = start + Number(slices[i].share) * Math.PI * 2;
                        ctx.beginPath();
                        ctx.moveTo(width / 2, height / 2);
                        ctx.arc(width / 2, height / 2, width / 2 - 2, start, end);
                        ctx.closePath();
                        ctx.fillStyle = MobileTheme.chartColors[i % MobileTheme.chartColors.length];
                        ctx.fill();
                        start = end;
                    }
                }
            }
            MobileText {
                Layout.fillWidth: true
                text: panel.percent(group.modelData.annualPercent)
                font.pixelSize: 40
                font.family: MobileTheme.serif
            }
            MobileText {
                Layout.fillWidth: true
                font.pixelSize: 12
                font.family: MobileTheme.mono
                color: MobileTheme.muted
                wrapMode: Text.Wrap
                text: qsTr("Учтено %1 из %2 · %3 сейчас").arg(group.modelData.counted).arg(group.modelData.shown).arg(MobileFormat.displayMoney(group.modelData.valueMinor, "RUB", false))
            }
            Repeater {
                model: group.modelData.slices || []
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        width: 8
                        height: 8
                        color: MobileTheme.chartColors[index % MobileTheme.chartColors.length]
                    }
                    MobileText {
                        Layout.fillWidth: true
                        text: modelData.title
                        wrapMode: Text.Wrap
                    }
                    MobileText {
                        text: Math.round(Number(modelData.share) * 100) + " %"
                        font.pixelSize: 12
                        font.family: MobileTheme.mono
                    }
                }
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: MobileTheme.line
    }
    MobileText {
        text: qsTr("СЧЕТА ДЛЯ РАСЧЁТА")
        font.pixelSize: 12
        font.family: MobileTheme.mono
    }
    MobileCheckRow {
        Layout.fillWidth: true
        label: qsTr("Объединить криптовалюту и инвестиции")
        checked: panel.merged
        onToggled: function (on) {
            financeController.setAverageReturnSelection(panel.excluded, on);
        }
    }
    Repeater {
        model: panel.items
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 4
            MobileCheckRow {
                Layout.fillWidth: true
                label: modelData.title
                checked: panel.excluded.indexOf(modelData.id) < 0
                onToggled: function (on) {
                    panel.setIncluded(modelData.id, on);
                }
            }
            MobileText {
                Layout.fillWidth: true
                Layout.leftMargin: 36
                font.pixelSize: 12
                font.family: MobileTheme.mono
                color: MobileTheme.muted
                wrapMode: Text.Wrap
                text: MobileFormat.displayMoney(modelData.valueMinor, "RUB", false) + " · " + (modelData.annualPercent === null || modelData.annualPercent === undefined ? modelData.reason : panel.percent(modelData.annualPercent) + qsTr(" в год"))
            }
            MobileButton {
                Layout.fillWidth: true
                Layout.leftMargin: 36
                visible: !!modelData.untracked
                text: modelData.basisMode ? qsTr("Цена покупки…") : qsTr("Указать цену покупки")
                onClicked: costBasisSheet.openFor(modelData)
            }
        }
    }
    MobileCostBasisSheet {
        id: costBasisSheet
    }
    MobileText {
        Layout.fillWidth: true
        visible: !panel.items.length
        text: qsTr("Добавьте позицию, вклад или кошелёк")
        color: MobileTheme.muted
        wrapMode: Text.Wrap
    }
    MobileText {
        Layout.fillWidth: true
        font.pixelSize: 12
        font.family: MobileTheme.mono
        color: MobileTheme.muted
        wrapMode: Text.Wrap
        text: qsTr("Вес инструмента — сумма денег в нём сейчас. Учитываются инструменты с историей не короче 30 дней. Криптовалюта — монеты на бирже по сделкам за два года; цена покупки переведена в рубли по курсу ЦБ на день сделки. Кошельки и стейблкоины не учитываются. Для монет с вводом или выводом причина исключения указана в списке.")
    }
}
