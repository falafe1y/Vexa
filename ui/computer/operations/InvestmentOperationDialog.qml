import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

EditorialDialog {
    id: dialog; objectName: "dialog"
    property var controller
    property var position: null
    property color panelColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF8")
    property color softColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF0")
    property color textColor: "#031528"
    property color mutedColor: (Appearance.desktop ? "#59616a" : "#687483")
    property color lineColor: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color accentColor: "#031528"
    property color hoverColor: (Appearance.desktop ? "#e9e4d8" : "#E4E8F1")
    property color errorColor: (Appearance.desktop ? "#b84932" : "#B94F48")
    property string localError: ""
    readonly property string kind: operationBox.currentValue || "buy"
    readonly property bool trade: kind === "buy" || kind === "sell"
    parent: Overlay.overlay; anchors.centerIn: parent; modal: true
    width: Math.min(parent ? parent.width - 32 : 640, 640)
    height: Math.min(parent ? parent.height - 32 : 760, 760)
    title: qsTr("Операция по инвестиции")
    standardButtons: Dialog.NoButton
    header: EditorialDialogTitle { text: dialog.title; color: dialog.textColor;   leftPadding: dialog.leftPadding; topPadding: dialog.topPadding }
    background: Rectangle { color: dialog.panelColor; radius: Appearance.desktop ? 0 : 16; border.width: 1; border.color: dialog.accentColor; HardShadow { visible: !Appearance.desktop;  depth: 6; shadowColor: dialog.accentColor } }
    function openFor(value) {
        position = value; localError = ""; operationBox.currentIndex = 0;
        quantityField.text = ""; priceField.text = ""; cashField.text = ""; feeField.text = ""; taxField.text = ""; remainingValueField.text = "";
        accruedField.text = "0"; faceField.text = value.faceValueText || "";
        dateField.text = Qt.formatDateTime(new Date(), "dd.MM.yyyy HH:mm:ss"); descriptionField.text = ""; open();
    }
    function operationKinds() {
        const sold = position && position.direction === -1;
        const kinds = [{name: sold ? qsTr("Продажа / увеличение позиции") : qsTr("Покупка / увеличение позиции"), value: "buy"},
            {name: sold ? qsTr("Покупка / уменьшение позиции") : qsTr("Продажа / уменьшение позиции"), value: "sell"}];
        if (position && position.type === 2) { kinds.push({name: qsTr("Купон"), value: "coupon"}); kinds.push({name: qsTr("Частичное погашение номинала"), value: "amortization"}); }
        if (position && [0,1,3,5,6].indexOf(position.type) >= 0) kinds.push({name: qsTr("Дивиденды / выплата фонда"), value: "dividend"});
        if (position && (position.type === 9 || position.pricing === "margined_option")) kinds.push({name: qsTr("Расчёт вариационной маржи"), value: "margin"});
        kinds.push({name: qsTr("Комиссия"), value: "fee"});
        if (position && [2,9,10].indexOf(position.type) >= 0) kinds.push({name: qsTr("Погашение / исполнение"), value: "expiry"});
        return kinds;
    }
    function submit() {
        const result = controller.recordInvestmentOperation({positionId: position.id, kind: kind,
            quantity: quantityField.text, price: priceField.text, cashAmount: cashField.text,
            remainingValue: remainingValueField.text, accruedAfter: accruedField.text, faceAfter: faceField.text,
            date: dateField.text, description: descriptionField.text, fee: dialog.kind === "fee" ? "" : feeField.text, tax: taxField.text});
        if (result.ok) close(); else localError = result.error || qsTr("Не удалось записать операцию");
    }
    component FormField: StyledTextField {
        Layout.minimumWidth: 0
        neo: true
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appOnAccentColor: dialog.panelColor
    }

    component FormCombo: StyledComboBox {
        Layout.minimumWidth: 0
        neo: true
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appHoverColor: dialog.hoverColor
    }

    component FormButton: StyledButton {
        neo: true
        cornerRadius: 8
        font.weight: Font.DemiBold
        appTextColor: dialog.textColor
        appMutedColor: dialog.mutedColor
        appPanelColor: dialog.panelColor
        appSoftColor: dialog.softColor
        appLineColor: dialog.lineColor
        appAccentColor: dialog.accentColor
        appHoverColor: dialog.hoverColor
        appOnAccentColor: dialog.panelColor
        appErrorColor: dialog.errorColor
    }


    contentItem: EditorialColumnLayout {
        spacing: 16
        EditorialScrollView {
            id: operationScroll; objectName: "operationScroll"
            contentWidth: availableWidth
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            EditorialColumnLayout {
                width: operationScroll.availableWidth; spacing: 8
                EditorialLabel { Layout.fillWidth: true; text: dialog.position ? dialog.position.symbol + " · " + dialog.position.accountName : ""; color: dialog.textColor; wrapMode: Text.WordWrap; font.pixelSize: 16 }
                FormCombo { id: operationBox; objectName: "operationBox"; Layout.fillWidth: true; model: dialog.operationKinds(); textRole: "name"; valueRole: "value" }
                EditorialLabel { text: qsTr("Дата и время фактической операции"); color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                FormField { id: dateField; objectName: "dateField"; Layout.fillWidth: true; placeholderText: qsTr("дд.мм.гггг чч:мм:сс") }
                EditorialLabel { text: qsTr("Изменение денег на счёте, %1").arg(dialog.position ? dialog.position.currency : ""); color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                FormField { id: cashField; objectName: "cashField"; Layout.fillWidth: true; placeholderText: qsTr("Со знаком: например, −1000 или 500") }
                EditorialLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr("Вводите фактическое движение денег с учётом комиссий и удержаний. Не добавляйте сюда стоимость всей позиции или обеспечение."); color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14 }
                EditorialLabel { Layout.fillWidth: true; text: qsTr("Комиссия и удержания уже входят в движение денег. Пустое поле — сумма неизвестна; 0 — списания не было."); color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14; wrapMode: Text.WordWrap }
                FormField { id: feeField; objectName: "feeField"; Layout.fillWidth: true; visible: dialog.kind !== "fee"; placeholderText: qsTr("Комиссия, %1 (необязательно)").arg(dialog.position ? dialog.position.currency : "") }
                FormField { id: taxField; objectName: "taxField"; Layout.fillWidth: true; placeholderText: qsTr("Удержания / налог, %1 (необязательно)").arg(dialog.position ? dialog.position.currency : "") }
                FormField { id: quantityField; objectName: "quantityField"; Layout.fillWidth: true; visible: dialog.trade; placeholderText: qsTr("Количество операции") }
                FormField { id: priceField; objectName: "priceField"; Layout.fillWidth: true; visible: dialog.trade || dialog.kind === "margin"; placeholderText: dialog.kind === "margin" ? qsTr("Цена проведённого расчёта") : qsTr("Цена сделки в единицах котировки") }
                FormField { id: remainingValueField; objectName: "remainingValueField"; Layout.fillWidth: true; visible: !!dialog.position && dialog.position.manualValuation && (dialog.trade || dialog.kind === "coupon" || dialog.kind === "amortization"); placeholderText: qsTr("Новая стоимость оставшейся позиции, %1").arg(dialog.position ? dialog.position.currency : "") }
                FormField { id: accruedField; objectName: "accruedField"; Layout.fillWidth: true; visible: dialog.kind === "coupon" || dialog.kind === "amortization"; placeholderText: qsTr("НКД одной облигации после операции") }
                FormField { id: faceField; objectName: "faceField"; Layout.fillWidth: true; visible: dialog.kind === "amortization"; placeholderText: qsTr("Оставшийся номинал одной облигации") }
                EditorialLabel { Layout.fillWidth: true; visible: dialog.kind === "coupon" || dialog.kind === "amortization"; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14; text: qsTr("Укажите НКД и оставшийся номинал после выплаты, чтобы выплаченная сумма не осталась в оценке облигации.") }
                EditorialLabel { Layout.fillWidth: true; visible: dialog.kind === "margin"; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14; text: qsTr("Деньги изменятся на указанную сумму. Дальнейшая переоценка начнётся от цены и времени этого расчёта.") }
                EditorialLabel { Layout.fillWidth: true; visible: dialog.kind === "expiry"; wrapMode: Text.WordWrap; color: dialog.mutedColor; font.pixelSize: Appearance.desktop ? 16 : 14; text: qsTr("Позиция закроется. Укажите итоговое движение денег; при поставке добавьте полученные активы как уже имеющуюся позицию.") }
                FormField { id: descriptionField; objectName: "descriptionField"; Layout.fillWidth: true; placeholderText: qsTr("Описание (необязательно)") }
            }
        }
        EditorialLabel { Layout.fillWidth: true; visible: dialog.localError.length > 0; text: dialog.localError; color: dialog.errorColor; wrapMode: Text.WordWrap; font.pixelSize: Appearance.desktop ? 16 : 14 }
        EditorialRowLayout { Layout.fillWidth: true; Item { Layout.fillWidth: true }
            FormButton { text: qsTr("Отмена"); onClicked: dialog.close() }
            FormButton { primary: true; text: qsTr("Записать"); enabled: !!dialog.position && !!dialog.controller; onClicked: dialog.submit() }
        }
    }
}
