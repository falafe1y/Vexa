import QtQuick
import QtQuick.Layouts

// The purchase price of the coins that have no trade behind them (deposit, bot, transfer).
// The user picks one of two modes; the return of the coin is then counted from that purchase.
MobileSheet {
    id: sheet

    property string itemId: ""
    property string itemTitle: ""
    property string basisMode: ""
    property string mode: "manual"
    property string errorText: ""

    title: "Цена покупки"

    function openFor(item) {
        itemId = item.id;
        itemTitle = item.title;
        basisMode = item.basisMode || "";
        mode = "manual";
        priceField.text = "";
        dateField.text = "";
        errorText = "";
        open();
    }

    function save() {
        sheet.errorText = "";
        const price = parseFloat(priceField.text.replace(",", "."));
        const saved = financeController.setCryptoCostBasis(
            sheet.itemId,
            sheet.mode,
            isNaN(price) ? 0 : price,
            dateField.text.trim());
        if (saved)
            sheet.close();
        else
            sheet.errorText = "Проверьте цену и дату: цена больше нуля, дата в формате ГГГГ-ММ-ДД и не позже сегодня.";
    }

    MobileText {
        Layout.fillWidth: true
        text: sheet.itemTitle
        font.pixelSize: MobileTheme.sizeBody
        font.family: MobileTheme.sans
        wrapMode: Text.Wrap
    }

    MobileText {
        Layout.fillWidth: true
        text: "Эти монеты попали на счёт не покупкой на бирже, поэтому доходность по ним нужна цена покупки."
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
        wrapMode: Text.Wrap
    }

    MobileSegmented {
        Layout.fillWidth: true
        options: [
            {
                label: "Средняя цена и дата",
                value: "manual"
            },
            {
                label: "С подключения",
                value: "connection"
            }
        ]
        value: sheet.mode
        onActivated: function (chosen) {
            sheet.mode = chosen;
        }
    }

    MobileText {
        Layout.fillWidth: true
        visible: sheet.mode === "connection"
        text: "Цена покупки будет равна цене на сегодня."
        color: MobileTheme.muted
        font.pixelSize: MobileTheme.sizeCaption
        wrapMode: Text.Wrap
    }

    MobileField {
        id: priceField
        visible: sheet.mode === "manual"
        Layout.fillWidth: true
        label: "Цена за 1 монету, $"
        placeholder: "0"
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    MobileField {
        id: dateField
        visible: sheet.mode === "manual"
        Layout.fillWidth: true
        label: "Примерная дата покупки"
        placeholder: "ГГГГ-ММ-ДД"
    }

    MobileText {
        font.family: MobileTheme.mono
        Layout.fillWidth: true
        visible: sheet.errorText.length > 0
        text: sheet.errorText
        wrapMode: Text.Wrap
        color: MobileTheme.red
        font.pixelSize: MobileTheme.sizeCaption
    }

    MobileButton {
        Layout.fillWidth: true
        variant: "primary"
        text: "Сохранить"
        onClicked: sheet.save()
    }

    MobileButton {
        Layout.fillWidth: true
        visible: sheet.basisMode.length > 0
        text: "Сбросить"
        onClicked: {
            if (financeController.clearCryptoCostBasis(sheet.itemId))
                sheet.close();
            else
                sheet.errorText = "Не удалось сбросить цену покупки";
        }
    }

    MobileButton {
        Layout.fillWidth: true
        text: "Отмена"
        onClicked: sheet.close()
    }
}
