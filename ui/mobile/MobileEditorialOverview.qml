import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../computer/dashboard/DashboardData.js" as Data

Flickable {
    id: dashboard
    required property var host
    readonly property var accounts: host.assetRows()
    readonly property var historyRows: host.historyRows()
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    pixelAligned: true
    contentWidth: width
    contentHeight: layout.implicitHeight + 24
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }
    TapHandler {
        id: outsideTap
        gesturePolicy: TapHandler.DragThreshold
        onTapped: function (eventPoint) {
            const point = history.mapFromItem(outsideTap.parent, eventPoint.position.x, eventPoint.position.y);
            if (!history.contains(point))
                dashboard.host.clearTransactionSelection();
        }
    }

    function revealSearch() {
        if (search.activeFocus)
            contentY = Math.min(search.mapToItem(contentItem, 0, 0).y - 16, Math.max(0, contentHeight - height));
    }
    Connections {
        target: Qt.inputMethod
        function onKeyboardRectangleChanged() {
            Qt.callLater(dashboard.revealSearch);
        }
        function onVisibleChanged() {
            Qt.callLater(dashboard.revealSearch);
        }
    }
    ColumnLayout {
        id: layout
        width: dashboard.width
        spacing: 20
        MobilePageHeader {
            Layout.fillWidth: true
            host: dashboard.host
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: summary.implicitHeight + 32
            color: MobileTheme.tableHeader
            Rectangle {
                width: parent.width
                height: 2
                color: MobileTheme.accent
            }
            ColumnLayout {
                id: summary
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 8
                MobileText {
                    font.family: MobileTheme.mono
                    text: qsTr("ВСЕ АКТИВЫ")
                    font.pixelSize: 12
                    color: MobileTheme.muted
                }
                MobileText {
                    Layout.fillWidth: true
                    font.family: MobileTheme.serif
                    font.pixelSize: dashboard.width < 328 ? 36 : 40
                    text: MobileFormat.money(Data.currentCapital(financeController), financeController.appCurrency, false)
                    elide: Text.ElideRight
                }
                MobileText {
                    font.family: MobileTheme.mono
                    text: qsTr("Счетов и кошельков: %1").arg(Data.accountCount(financeController.allAccounts, financeController.cryptoWallets, "all"))
                    font.pixelSize: 12
                    color: MobileTheme.muted
                }
                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    visible: financeController.investmentValuationIncomplete
                    text: qsTr("Для части инвестиций нужна котировка, курс или ручная оценка")
                    font.pixelSize: 12
                    color: MobileTheme.muted
                    wrapMode: Text.Wrap
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    {
                        key: "fiat",
                        name: qsTr("Фиат")
                    },
                    {
                        key: "crypto",
                        name: qsTr("Крипто")
                    },
                    {
                        key: "investment",
                        name: qsTr("Инвестиции")
                    }
                ]
                delegate: Button {
                    required property var modelData
                    readonly property bool current: financeController.selectedAsset === modelData.key
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 72
                    padding: 8
                    contentItem: ColumnLayout {
                        spacing: 4
                        MobileText {
                            font.family: MobileTheme.sans
                            Layout.fillWidth: true
                            text: modelData.name
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        MobileText {
                            font.family: MobileTheme.mono
                            text: qsTr("Счетов: %1").arg(Data.accountCount(financeController.allAccounts, financeController.cryptoWallets, modelData.key))
                            font.pixelSize: 12
                            color: MobileTheme.muted
                        }
                    }
                    background: Rectangle {
                        color: parent.current ? MobileTheme.pale : "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.parent.current ? 2 : 1
                            color: parent.parent.current ? MobileTheme.accent : MobileTheme.line
                        }
                    }
                    onClicked: {
                        dashboard.host.clearTransactionSelection();
                        financeController.selectedAsset = modelData.key;
                        dashboard.host.clearHistoryAccount();
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: qsTr("01. СЧЕТА")
                    font.pixelSize: 12
                }
                MobileChip {
                    text: qsTr("Добавить")
                    onClicked: dashboard.host.addAccount()
                }
            }
            ListView {
                id: accountList
                objectName: "dashboardAccounts"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(224, Math.max(72, contentHeight))
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                pixelAligned: true
                model: dashboard.accounts
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                delegate: Rectangle {
                    id: account
                    required property var modelData
                    width: accountList.width
                    height: accountContent.implicitHeight + 32
                    color: dashboard.host.historyAccountId === modelData.id ? MobileTheme.pale : "transparent"
                    RowLayout {
                        id: accountContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 16
                        spacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4
                            MobileText {
                                font.family: MobileTheme.sans
                                Layout.fillWidth: true
                                text: account.modelData.name
                                font.pixelSize: 16
                                elide: Text.ElideRight
                            }
                            MobileText {
                                font.family: MobileTheme.mono
                                Layout.fillWidth: true
                                // While the wallet or the exchange syncs, the progress takes the place of the address
                                text: account.modelData.refreshing ? dashboard.host.cryptoWalletStatus(account.modelData) : account.modelData.isCrypto ? (account.modelData.symbol || "") + " · " + (account.modelData.network || "") + " · " + (account.modelData.address || "") : dashboard.host.accountTypeLabel(account.modelData.type)
                                font.pixelSize: 12
                                color: MobileTheme.muted
                                elide: Text.ElideRight
                            }
                        }
                        MobileText {
                            Layout.maximumWidth: accountList.width * 0.56
                            text: dashboard.host.hideAmounts ? "******" : account.modelData.isCreditCard ? qsTr("Долг %1").arg(MobileFormat.money(account.modelData.debtMinor, account.modelData.currency, false)) : dashboard.host.rowPrimaryAmount(account.modelData)
                            font.pixelSize: 20
                            font.family: MobileTheme.serif
                            elide: Text.ElideRight
                        }
                        MobileIconButton {
                            id: accountMenuButton
                            icon: "more"
                            onClicked: dashboard.host.openAccountContextMenu(account.modelData, this, 0, height)
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: MobileTheme.line
                    }
                    TapHandler {
                        onTapped: {
                            const local = accountMenuButton.mapFromItem(account, point.position.x, point.position.y);
                            if (!accountMenuButton.contains(local))
                                dashboard.host.selectHistoryAccount(account.modelData);
                        }
                        onLongPressed: dashboard.host.openAccountContextMenu(account.modelData, account, point.position.x, point.position.y)
                    }
                }
                MobileText {
                    font.family: MobileTheme.mono
                    anchors.centerIn: parent
                    visible: accountList.count === 0
                    text: qsTr("Счетов пока нет")
                    font.pixelSize: 12
                    color: MobileTheme.muted
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: financeController.selectedAsset === "investment"
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                MobileText {
                    Layout.fillWidth: true
                    text: qsTr("ПОЗИЦИИ")
                    font.pixelSize: 12
                    font.family: MobileTheme.mono
                }
                MobileChip {
                    text: qsTr("Добавить")
                    enabled: financeController.investmentAccounts.length > 0
                    onClicked: dashboard.host.addPosition()
                }
            }
            MobileButton {
                Layout.fillWidth: true
                text: financeController.investmentRefreshing ? qsTr("Обновляем…") : qsTr("Обновить цены")
                enabled: !financeController.investmentRefreshing
                onClicked: financeController.refreshInvestmentQuotes()
            }
            Repeater {
                model: financeController.selectedAsset === "investment" ? financeController.investmentPositions.filter(function (row) {
                    return !financeController.selectedAccountId || row.accountId === financeController.selectedAccountId;
                }) : []
                delegate: MobileCard {
                    required property var modelData
                    Layout.fillWidth: true
                    cardPadding: 8
                    gap: 8
                    MobileText {
                        Layout.fillWidth: true
                        text: modelData.symbol + " · " + modelData.name
                        font.pixelSize: 24
                        wrapMode: Text.Wrap
                    }
                    MobileText {
                        Layout.fillWidth: true
                        text: modelData.quantityText + " " + (modelData.quantityUnit || "") + " · " + (MobileTheme.hideAmounts ? "******" : (modelData.hasQuote ? MobileFormat.money(modelData.marketValueMinor, modelData.currency, false) : qsTr("Цена недоступна")))
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    MobileText {
                        Layout.fillWidth: true
                        font.pixelSize: 12
                        font.family: MobileTheme.mono
                        text: (modelData.accountName || "") + " · " + (modelData.valuationLabel || "")
                        wrapMode: Text.Wrap
                        color: MobileTheme.muted
                    }
                    MobileText {
                        Layout.fillWidth: true
                        font.pixelSize: 12
                        font.family: MobileTheme.mono
                        text: modelData.hasMarketQuote && !modelData.manualValuation ? (modelData.priceText || "") + " " + (modelData.type === 2 ? "%" : modelData.type >= 9 ? qsTr("пункт.") : (modelData.quoteCurrency || "")) + " · " + (modelData.quoteSourceLabel || "") : ""
                        visible: text.length > 0
                        wrapMode: Text.Wrap
                        color: MobileTheme.muted
                    }
                    MobileText {
                        Layout.fillWidth: true
                        font.pixelSize: 12
                        font.family: MobileTheme.mono
                        text: (modelData.valuationError || "") + (modelData.manualValuation ? (modelData.valuedAtText || "") : (modelData.quotedAtText || ""))
                        visible: text.length > 0
                        wrapMode: Text.Wrap
                        color: MobileTheme.muted
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        MobileButton {
                            Layout.fillWidth: true
                            text: qsTr("Операция")
                            onClicked: dashboard.host.positionOperation(modelData)
                        }
                        MobileIconButton {
                            icon: "sliders"
                            Accessible.name: qsTr("Изменить позицию")
                            onClicked: dashboard.host.editPosition(modelData)
                        }
                        MobileIconButton {
                            icon: "trash"
                            Accessible.name: qsTr("Удалить позицию")
                            onClicked: financeController.deleteInvestmentPosition(modelData.id)
                        }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: financeController.selectedAsset === "crypto"
            spacing: 8
            MobileText {
                Layout.fillWidth: true
                visible: financeController.cryptoRefreshing || !!financeController.cryptoLastError
                text: financeController.cryptoRefreshing ? qsTr("Обновляем балансы и историю…") : financeController.cryptoLastError
                font.pixelSize: 12
                color: MobileTheme.muted
                wrapMode: Text.Wrap
            }
            MobileButton {
                Layout.fillWidth: true
                text: qsTr("Обновить цены")
                enabled: !financeController.cryptoRefreshing && financeController.cryptoManualRefreshReady
                onClicked: financeController.refreshCryptoWallets()
            }
            Repeater {
                model: {
                    financeController.cryptoWallets;
                    return financeController.selectedAsset === "crypto" ? financeController.cryptoExchangeHoldings() : [];
                }
                delegate: MobileListRow {
                    required property var modelData
                    Layout.fillWidth: true
                    title: modelData.accountName + " · " + dashboard.host.exchangeSection(modelData.section)
                    subtitle: modelData.category || ""
                    amount: MobileTheme.hideAmounts ? "******" : modelData.summary ? MobileFormat.money(Math.round(Number(modelData.usdValue) * 100), "USD", false) : String(modelData.amountText) + " " + modelData.coin
                }
            }
        }
        ColumnLayout {
            id: history
            objectName: "dashboardHistory"
            Layout.fillWidth: true
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                MobileText {
                    font.family: MobileTheme.mono
                    Layout.fillWidth: true
                    text: qsTr("02. ИСТОРИЯ ОПЕРАЦИЙ")
                    font.pixelSize: 12
                }
                MobileIconButton {
                    icon: "sliders"
                    onClicked: sortSheet.open()
                }
            }
            TextField {
                id: search
                objectName: "historySearch"
                Layout.fillWidth: true
                implicitHeight: 48
                leftPadding: 0
                rightPadding: 32
                font.family: MobileTheme.sans
                font.pixelSize: 16
                color: MobileTheme.accent
                placeholderTextColor: MobileTheme.muted
                placeholderText: qsTr("Поиск по истории")
                text: dashboard.host.searchText
                onTextEdited: dashboard.host.searchText = text
                onActiveFocusChanged: Qt.callLater(dashboard.revealSearch)
                background: Item {
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: MobileTheme.line
                    }
                }
                MobileIcon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    width: 20
                    height: 20
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                MobileChip {
                    visible: !!dashboard.host.historyAccountId
                    text: dashboard.host.accountName(dashboard.host.historyAccountId) + " ×"
                    onClicked: dashboard.host.clearHistoryAccount()
                }
                MobileChip {
                    visible: !!dashboard.host.historyCategory
                    text: dashboard.host.historyCategory + " ×"
                    onClicked: dashboard.host.historyCategory = ""
                }
            }
            Repeater {
                model: dashboard.historyRows
                delegate: Rectangle {
                    id: operation
                    objectName: "historyOperation"
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: operationContent.implicitHeight + 32
                    color: dashboard.host.isTransactionSelected(modelData.source) ? MobileTheme.pale : "transparent"
                    ColumnLayout {
                        id: operationContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 16
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MobileText {
                                font.family: MobileTheme.mono
                                Layout.fillWidth: true
                                text: Qt.formatDate(operation.modelData.date, "dd.MM.yyyy")
                                font.pixelSize: 12
                                color: MobileTheme.muted
                            }
                            MobileText {
                                Layout.maximumWidth: history.width * 0.65
                                text: dashboard.host.hideAmounts ? "******" : operation.modelData.amount
                                font.family: MobileTheme.serif
                                font.pixelSize: 24
                                elide: Text.ElideRight
                                color: operation.modelData.signed > 0 ? MobileTheme.income : MobileTheme.accent
                            }
                        }
                        MobileText {
                            font.family: MobileTheme.sans
                            Layout.fillWidth: true
                            text: operation.modelData.description
                            wrapMode: Text.Wrap
                            font.pixelSize: 16
                        }
                        MobileText {
                            font.family: MobileTheme.mono
                            Layout.fillWidth: true
                            text: operation.modelData.account + " · " + operation.modelData.category
                            wrapMode: Text.Wrap
                            font.pixelSize: 12
                            color: MobileTheme.muted
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: MobileTheme.line
                    }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: dashboard.host.toggleTransactionSelection(operation.modelData.source)
                        onLongPressed: {
                            if (!dashboard.host.isTransactionSelected(operation.modelData.source))
                                dashboard.host.toggleTransactionSelection(operation.modelData.source);
                            dashboard.host.openSelectionMenu(operation, point.position.x, point.position.y);
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            if (!dashboard.host.isTransactionSelected(operation.modelData.source))
                                dashboard.host.toggleTransactionSelection(operation.modelData.source);
                            dashboard.host.openSelectionMenu(operation, point.position.x, point.position.y);
                        }
                    }
                }
            }
            MobileText {
                Layout.fillWidth: true
                visible: dashboard.historyRows.length === 0
                text: qsTr("Операций не найдено")
                color: MobileTheme.muted
                topPadding: 24
                bottomPadding: 24
            }
        }
    }
    MobileSheet {
        id: sortSheet
        title: qsTr("Сортировка истории")
        Repeater {
            model: [
                {
                    key: "date",
                    label: qsTr("Дата")
                },
                {
                    key: "type",
                    label: qsTr("Тип")
                },
                {
                    key: "account",
                    label: qsTr("Счёт")
                },
                {
                    key: "category",
                    label: qsTr("Категория")
                },
                {
                    key: "description",
                    label: qsTr("Описание")
                },
                {
                    key: "amount",
                    label: qsTr("Сумма")
                }
            ]
            MobileListRow {
                required property var modelData
                Layout.fillWidth: true
                title: modelData.label
                marked: dashboard.host.historySort === modelData.key
                onClicked: {
                    dashboard.host.historySort = modelData.key;
                    sortSheet.close();
                }
            }
        }
        MobileSegmented {
            Layout.fillWidth: true
            options: [
                {
                    label: qsTr("По возрастанию"),
                    value: 1
                },
                {
                    label: qsTr("По убыванию"),
                    value: -1
                }
            ]
            value: dashboard.host.historyDirection
            onActivated: function (chosen) {
                dashboard.host.historyDirection = chosen;
            }
        }
    }
}
