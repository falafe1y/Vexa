import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window

    required property var ledger

    property string errorText: ""

    width: 1280
    height: 800

    minimumWidth: 1100
    minimumHeight: 700

    visible: true
    title: "Vexa"

    function syncModel(target, items) {
        for (let i = 0; i < items.length; ++i) {
            const row = items[i]
            let position = -1

            for (let j = i; j < target.count; ++j) {
                if (target.get(j).id === row.id) {
                    position = j
                    break
                }
            }

            if (position < 0) {
                target.insert(i, row)
                continue
            }

            if (position !== i) {
                target.move(position, i, 1)
            }

            const previous = target.get(i)

            for (const role in row) {
                if (previous[role] !== row[role]) {
                    target.setProperty(i, role, row[role])
                }
            }
        }

        if (target.count > items.length) {
            target.remove(
                items.length,
                target.count - items.length
            )
        }
    }

    function askRemoval(commandName, recordId, description) {
        removeDialog.commandName = commandName
        removeDialog.recordId = recordId
        removeDialog.description = description
        removeDialog.errorText = ""
        removeDialog.open()
    }

    ListModel {
        id: accountsModel
    }

    ListModel {
        id: categoriesModel
    }

    ListModel {
        id: historyModel
    }

    Connections {
        target: window.ledger

        function onAccountsReceived(items) {
            window.syncModel(accountsModel, items)
        }

        function onCategoriesReceived(items) {
            window.syncModel(categoriesModel, items)
        }

        function onHistoryReceived(items, replace) {
            if (replace) {
                historyModel.clear()
            }

            for (let i = 0; i < items.length; ++i) {
                historyModel.append(items[i])
            }
        }

        function onErrorOccurred(message) {
            window.errorText = message
        }
    }

    AccountDialog {
        id: accountDialog

        ledger: window.ledger
    }

    CategoryDialog {
        id: categoryDialog

        ledger: window.ledger
    }

    OperationDialog {
        id: operationDialog

        ledger: window.ledger
        accountsModel: accountsModel
        categoriesModel: categoriesModel
    }

    header: ToolBar {
        height: 56

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Label {
                text: "Vexa"
                font.pixelSize: 24
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                text: window.ledger.ready
                      ? "База загружена"
                      : "Загрузка…"
            }

            Button {
                text: "Обновить"

                enabled: window.ledger.ready
                         && !window.ledger.commandPending

                onClicked: {
                    window.errorText = ""
                    window.ledger.refresh()
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16

        spacing: 16

        Label {
            Layout.fillWidth: true

            visible: window.errorText.length > 0
            text: window.errorText
            color: "#c62828"
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            spacing: 20

            ColumnLayout {
                Layout.preferredWidth: 150
                Layout.fillHeight: true

                Button {
                    Layout.fillWidth: true
                    text: "Главная"

                    onClicked: pages.currentIndex = 0
                }

                Button {
                    Layout.fillWidth: true
                    text: "Категории"

                    onClicked: pages.currentIndex = 1
                }

                Button {
                    Layout.fillWidth: true
                    text: "История"

                    onClicked: pages.currentIndex = 2
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            StackLayout {
                id: pages

                Layout.fillWidth: true
                Layout.fillHeight: true

                currentIndex: 0

                // Главная.
                ScrollView {
                    id: dashboard

                    clip: true
                    contentWidth: availableWidth

                    Column {
                        width: dashboard.availableWidth
                        spacing: 20

                        Label {
                            text: "Общий итог: "
                                  + window.ledger.totalBalanceText

                            font.pixelSize: 28
                            font.bold: true
                        }

                        Row {
                            spacing: 8

                            Button {
                                text: "Новый счёт"

                                enabled: window.ledger.ready
                                         && !window.ledger.commandPending

                                onClicked: accountDialog.open()
                            }

                            Button {
                                text: "Доход"

                                enabled: window.ledger.ready
                                         && !window.ledger.commandPending
                                         && accountsModel.count > 0

                                onClicked: operationDialog.openFor(0)
                            }

                            Button {
                                text: "Расход"

                                enabled: window.ledger.ready
                                         && !window.ledger.commandPending
                                         && accountsModel.count > 0

                                onClicked: operationDialog.openFor(1)
                            }

                            Button {
                                text: "Перевод"

                                enabled: window.ledger.ready
                                         && !window.ledger.commandPending
                                         && accountsModel.count > 1

                                onClicked: operationDialog.openFor(2)
                            }
                        }

                        Label {
                            visible: accountsModel.count === 0
                            text: "Создайте первый счёт."
                        }

                        Flow {
                            width: parent.width
                            spacing: 16

                            Repeater {
                                model: accountsModel

                                delegate: Frame {
                                    id: accountCard

                                    required property var model

                                    width: 290

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 12

                                        Label {
                                            Layout.fillWidth: true

                                            text: accountCard.model.name
                                            font.pixelSize: 20
                                            font.bold: true

                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            text: accountCard.model.isCreditCard
                                                  ? "Доступно"
                                                  : "Остаток"
                                        }

                                        Label {
                                            text: accountCard.model.isCreditCard
                                                  ? accountCard.model.availableBalanceText
                                                  : accountCard.model.balanceText

                                            font.pixelSize: 24
                                        }

                                        Label {
                                            visible: accountCard.model.isCreditCard

                                            text: "Лимит: "
                                                  + accountCard.model.creditLimitText
                                        }

                                        Label {
                                            visible: accountCard.model.isCreditCard

                                            text: "Долг: "
                                                  + accountCard.model.debtText
                                        }

                                        Button {
                                            text: "Убрать счёт"

                                            enabled: !window.ledger.commandPending

                                            onClicked: window.askRemoval(
                                                "removeAccount",
                                                String(accountCard.model.id),
                                                accountCard.model.name
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Категории.
                ColumnLayout {
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: "Категории"
                            font.pixelSize: 26
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "Новая категория"

                            enabled: window.ledger.ready
                                     && !window.ledger.commandPending

                            onClicked: categoryDialog.open()
                        }
                    }

                    Label {
                        visible: categoriesModel.count === 0
                        text: "Категорий пока нет."
                    }

                    ListView {
                        id: categoriesList

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true
                        spacing: 8
                        model: categoriesModel

                        ScrollBar.vertical: ScrollBar {}

                        delegate: Frame {
                            id: categoryRow

                            required property var model

                            width: categoriesList.width
                            height: 64

                            RowLayout {
                                anchors.fill: parent
                                spacing: 16

                                Label {
                                    Layout.fillWidth: true

                                    text: categoryRow.model.name
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: categoryRow.model.typeText
                                }

                                Button {
                                    text: "Убрать"

                                    enabled: !window.ledger.commandPending

                                    onClicked: window.askRemoval(
                                        "removeCategory",
                                        String(categoryRow.model.id),
                                        categoryRow.model.name
                                    )
                                }
                            }
                        }
                    }
                }

                // История.
                ColumnLayout {
                    spacing: 12

                    Label {
                        text: "История"
                        font.pixelSize: 26
                    }

                    Label {
                        visible: historyModel.count === 0
                                 && !window.ledger.historyLoading

                        text: "Операций пока нет."
                    }

                    ListView {
                        id: historyList

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true
                        spacing: 4
                        model: historyModel

                        ScrollBar.vertical: ScrollBar {}

                        header: RowLayout {
                            width: historyList.width
                            height: 40
                            spacing: 10

                            Label {
                                Layout.preferredWidth: 90
                                text: "Дата"
                                font.bold: true
                            }

                            Label {
                                Layout.preferredWidth: 75
                                text: "Тип"
                                font.bold: true
                            }

                            Label {
                                Layout.preferredWidth: 190
                                text: "Счёт"
                                font.bold: true
                            }

                            Label {
                                Layout.preferredWidth: 160
                                text: "Сумма"
                                font.bold: true
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "Категория"
                                font.bold: true
                            }

                            Item {
                                Layout.preferredWidth: 85
                            }
                        }

                        delegate: Item {
                            id: historyRow

                            required property var model

                            width: historyList.width
                            height: 72

                            RowLayout {
                                anchors.fill: parent
                                spacing: 10

                                Label {
                                    Layout.preferredWidth: 90
                                    text: historyRow.model.dateText
                                }

                                Label {
                                    Layout.preferredWidth: 75
                                    text: historyRow.model.typeText
                                }

                                Label {
                                    Layout.preferredWidth: 190

                                    text: historyRow.model.isTransfer
                                          ? historyRow.model.accountName
                                            + " → "
                                            + historyRow.model.toAccountName
                                          : historyRow.model.accountName

                                    wrapMode: Text.Wrap
                                }

                                Label {
                                    Layout.preferredWidth: 160

                                    text: historyRow.model.isTransfer
                                          ? historyRow.model.amountText
                                            + "\n→ "
                                            + historyRow.model.receivedAmountText
                                          : historyRow.model.amountText

                                    wrapMode: Text.Wrap
                                }

                                Label {
                                    Layout.fillWidth: true

                                    text: historyRow.model.isTransfer
                                          ? "—"
                                          : historyRow.model.categoryName

                                    elide: Text.ElideRight
                                }

                                Button {
                                    Layout.preferredWidth: 85

                                    text: "Удалить"
                                    enabled: !window.ledger.commandPending

                                    onClicked: window.askRemoval(
                                        "removeOperation",
                                        String(historyRow.model.id),
                                        historyRow.model.dateText
                                        + " — "
                                        + historyRow.model.amountText
                                    )
                                }
                            }
                        }

                        footer: Item {
                            width: historyList.width
                            height: 64

                            Button {
                                anchors.centerIn: parent

                                visible: window.ledger.historyHasMore
                                         || window.ledger.historyLoading

                                text: window.ledger.historyLoading
                                      ? "Загрузка…"
                                      : "Следующие операции"

                                enabled: !window.ledger.historyLoading
                                         && window.ledger.historyHasMore

                                onClicked: window.ledger.loadMoreHistory()
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: removeDialog

        property string commandName: ""
        property string recordId: ""
        property string description: ""
        property string errorText: ""

        parent: Overlay.overlay

        width: Math.min(480, parent.width - 40)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        title: commandName === "removeOperation"
               ? "Удаление операции"
               : "Убрать запись"

        modal: true
        focus: true

        closePolicy: window.ledger.commandPending
                     ? Popup.NoAutoClose
                     : Popup.CloseOnEscape

        Connections {
            target: window.ledger

            function onCommandFinished(commandName, id) {
                if (removeDialog.visible
                    && commandName === removeDialog.commandName) {
                    removeDialog.close()
                }
            }

            function onErrorOccurred(message) {
                if (removeDialog.visible) {
                    removeDialog.errorText = message
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 12

            Label {
                Layout.fillWidth: true

                text: removeDialog.description
                wrapMode: Text.Wrap
                font.bold: true
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap

                text: removeDialog.commandName === "removeOperation"
                      ? "Удалить операцию? Остатки счетов будут пересчитаны."
                      : "Использованная запись будет архивирована. "
                        + "Неиспользованная — удалена. "
                        + "История сохранится."
            }

            Label {
                Layout.fillWidth: true

                visible: removeDialog.errorText.length > 0
                text: removeDialog.errorText

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
                enabled: !window.ledger.commandPending

                onClicked: removeDialog.close()
            }

            Button {
                text: window.ledger.commandPending
                      ? "Выполнение…"
                      : "Подтвердить"

                enabled: !window.ledger.commandPending

                onClicked: {
                    removeDialog.errorText = ""

                    if (removeDialog.commandName === "removeAccount") {
                        window.ledger.removeAccount(removeDialog.recordId)
                    } else if (
                        removeDialog.commandName === "removeCategory"
                    ) {
                        window.ledger.removeCategory(removeDialog.recordId)
                    } else {
                        window.ledger.removeOperation(removeDialog.recordId)
                    }
                }
            }
        }
    }
}
