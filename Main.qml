import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window

    required property var ledger

    property string errorText: ""

    width: 900
    height: 600
    visible: true
    title: "Vexa"

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
            accountsModel.clear()

            for (let i = 0; i < items.length; ++i) {
                accountsModel.append(items[i])
            }
        }

        function onCategoriesReceived(items) {
            categoriesModel.clear()

            for (let i = 0; i < items.length; ++i) {
                categoriesModel.append(items[i])
            }
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
            console.error(message)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        spacing: 16

        Label {
            text: window.ledger.ready
                  ? "База загружена"
                  : "Открываем базу…"
        }

        Label {
            text: "Общий итог: "
                  + window.ledger.totalBalanceText

            font.pixelSize: 26
        }

        Label {
            text: "Счетов: " + accountsModel.count
        }

        Label {
            text: "Категорий: " + categoriesModel.count
        }

        Label {
            text: "Получено операций: " + historyModel.count
        }

        RowLayout {
            spacing: 12

            Button {
                text: "Обновить"
                enabled: window.ledger.ready

                onClicked: {
                    window.errorText = ""
                    window.ledger.refresh()
                }
            }

            Button {
                text: window.ledger.historyLoading
                      ? "Загрузка…"
                      : "Следующие операции"

                enabled: window.ledger.ready
                         && !window.ledger.historyLoading
                         && window.ledger.historyHasMore

                onClicked: window.ledger.loadMoreHistory()
            }
        }

        Label {
            Layout.fillWidth: true

            visible: window.errorText.length > 0
            text: window.errorText

            color: "#c62828"
            wrapMode: Text.Wrap
        }

        Item {
            Layout.fillHeight: true
        }
    }
}