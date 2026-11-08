import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: dialog

    required property var ledger
    required property var accountsModel
    required property var categoriesModel

    // 0 — доход, 1 — расход, 2 — перевод.
    property int operationType: 0
    property string errorText: ""

    readonly property bool isTransfer: operationType === 2

    parent: Overlay.overlay

    width: Math.min(500, parent.width - 40)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    title: operationType === 0
           ? "Доход"
           : operationType === 1
             ? "Расход"
             : "Перевод"

    modal: true
    focus: true

    closePolicy: ledger.commandPending
                 ? Popup.NoAutoClose
                 : Popup.CloseOnEscape

    function rebuildCategories() {
        suitableCategories.clear()

        if (!isTransfer) {
            for (let i = 0; i < categoriesModel.count; ++i) {
                const category = categoriesModel.get(i)

                if (category.type === operationType) {
                    suitableCategories.append({
                        id: category.id,
                        name: category.name
                    })
                }
            }
        }

        categoryBox.currentIndex =
                suitableCategories.count > 0 ? 0 : -1
    }

    function openFor(type) {
        operationType = type
        errorText = ""

        amountField.text = ""
        dateField.text = Qt.formatDate(new Date(), "yyyy-MM-dd")

        accountBox.currentIndex =
                accountsModel.count > 0 ? 0 : -1

        receiverBox.currentIndex =
                accountsModel.count > 1 ? 1 : -1

        rebuildCategories()
        open()
    }

    function accountCurrency() {
        const index = accountBox.currentIndex

        if (index < 0 || index >= accountsModel.count) {
            return ""
        }

        return accountsModel.get(index).currencyCode
    }

    function selectedId(box) {
        return box.currentIndex >= 0
                ? String(box.currentValue)
                : ""
    }

    function submit() {
        errorText = ""

        const accountId = selectedId(accountBox)

        if (operationType === 0) {
            ledger.addIncome(
                accountId,
                selectedId(categoryBox),
                amountField.text,
                dateField.text
            )
        } else if (operationType === 1) {
            ledger.addExpense(
                accountId,
                selectedId(categoryBox),
                amountField.text,
                dateField.text
            )
        } else {
            ledger.transfer(
                accountId,
                selectedId(receiverBox),
                amountField.text,
                dateField.text
            )
        }
    }

    ListModel {
        id: suitableCategories
    }

    Connections {
        target: dialog.categoriesModel

        function onCountChanged() {
            if (dialog.visible) {
                dialog.rebuildCategories()
            }
        }
    }

    Connections {
        target: dialog.ledger

        function onCommandFinished(commandName, id) {
            const expected = dialog.operationType === 0
                             ? "income"
                             : dialog.operationType === 1
                               ? "expense"
                               : "transfer"

            if (dialog.visible && commandName === expected) {
                dialog.close()
            }
        }

        function onErrorOccurred(message) {
            if (dialog.visible) {
                dialog.errorText = message
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        Label {
            text: dialog.isTransfer
                  ? "Счёт отправителя"
                  : "Счёт"
        }

        ComboBox {
            id: accountBox

            Layout.fillWidth: true
            enabled: !dialog.ledger.commandPending

            model: dialog.accountsModel
            textRole: "name"
            valueRole: "id"
        }

        Label {
            visible: dialog.isTransfer
            text: "Счёт получателя"
        }

        ComboBox {
            id: receiverBox

            Layout.fillWidth: true

            visible: dialog.isTransfer
            enabled: !dialog.ledger.commandPending

            model: dialog.accountsModel
            textRole: "name"
            valueRole: "id"
        }

        Label {
            visible: !dialog.isTransfer
            text: "Категория"
        }

        ComboBox {
            id: categoryBox

            Layout.fillWidth: true

            visible: !dialog.isTransfer
            enabled: !dialog.ledger.commandPending

            model: suitableCategories
            textRole: "name"
            valueRole: "id"
        }

        Label {
            Layout.fillWidth: true

            visible: !dialog.isTransfer
                     && suitableCategories.count === 0

            wrapMode: Text.Wrap
            text: "Сначала создайте категорию подходящего типа."
        }

        Label {
            text: (dialog.isTransfer ? "Сумма списания, " : "Сумма, ")
                  + dialog.accountCurrency()
        }

        TextField {
            id: amountField

            Layout.fillWidth: true
            enabled: !dialog.ledger.commandPending

            placeholderText: "Например, 1500,50"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }

        Label {
            Layout.fillWidth: true

            visible: dialog.isTransfer
            wrapMode: Text.Wrap

            text: "Зачисление рассчитывается по текущим фиксированным курсам."
        }

        Label {
            text: "Дата"
        }

        TextField {
            id: dateField

            Layout.fillWidth: true
            enabled: !dialog.ledger.commandPending

            placeholderText: "ГГГГ-ММ-ДД"
        }

        Label {
            Layout.fillWidth: true

            visible: dialog.isTransfer
                     && accountBox.currentIndex >= 0
                     && receiverBox.currentIndex >= 0
                     && accountBox.currentValue === receiverBox.currentValue

            text: "Выберите разные счета."
            color: "#c62828"
        }

        Label {
            Layout.fillWidth: true

            visible: dialog.errorText.length > 0
            text: dialog.errorText
            color: "#c62828"
            wrapMode: Text.Wrap
        }
    }

    footer: RowLayout {
        spacing: 8

        Item {
            Layout.fillWidth: true
        }

        Button {
            text: "Отмена"
            enabled: !dialog.ledger.commandPending

            onClicked: dialog.close()
        }

        Button {
            text: dialog.ledger.commandPending
                  ? "Сохранение…"
                  : "Добавить"

            enabled: !dialog.ledger.commandPending
                     && accountBox.currentIndex >= 0
                     && amountField.text.trim().length > 0
                     && (dialog.isTransfer
                         ? receiverBox.currentIndex >= 0
                           && accountBox.currentValue !== receiverBox.currentValue
                         : categoryBox.currentIndex >= 0)

            onClicked: dialog.submit()
        }
    }
}
