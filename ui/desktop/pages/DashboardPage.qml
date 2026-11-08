import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Item {
    id: page
    required property var ledger
    signal createAccountRequested()
    signal operationRequested(int type)
    signal removeAccountRequested(string recordId, string description)
    signal removeOperationRequested(string recordId, string description)

    ListView {
        id: history
        anchors.fill: parent
        anchors.margins: 24
        clip: true
        model: page.ledger.historyModel
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        headerPositioning: ListView.InlineHeader
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        header: Column {
            width: history.width
            spacing: 24

            PageHeading {
                width: parent.width
                caption: "ЛИЧНЫЙ УЧЁТ / ОБЗОР"
                title: "Мои финансы."
            }
            AssetSummary {
                width: parent.width
                height: 154
                totalText: page.ledger.totalBalanceText
                accountsCaption: page.ledger.accountsCaption
            }
            AccountsSection {
                width: parent.width
                ledger: page.ledger
                onCreateRequested: page.createAccountRequested()
                onRemoveRequested: (recordId, description) =>
                    page.removeAccountRequested(recordId, description)
            }
            Rectangle {
                width: parent.width
                height: 1
                color: DesktopTheme.ink
            }
            RowLayout {
                width: parent.width
                EditorialText {
                    Layout.fillWidth: true
                    text: "02. / РЕЕСТР ОПЕРАЦИЙ"
                    font.family: DesktopTheme.mono
                    font.pixelSize: 12
                    font.bold: true
                }
                ActionButton {
                    text: "+ ОПЕРАЦИЯ"
                    enabled: page.ledger.canAddOperation
                    onClicked: operationMenu.open()
                    Menu {
                        id: operationMenu
                        y: parent.height
                        MenuItem {
                            text: "Доход"
                            onTriggered: page.operationRequested(0)
                        }
                        MenuItem {
                            text: "Расход"
                            onTriggered: page.operationRequested(1)
                        }
                        MenuItem {
                            text: "Перевод"
                            enabled: page.ledger.canTransfer
                            onTriggered: page.operationRequested(2)
                        }
                    }
                }
            }
            HistoryRow {
                width: parent.width
                heading: true
                dateText: "ДАТА"
                typeText: "ТИП"
                accountText: "СЧЁТ"
                categoryText: "КАТЕГОРИЯ"
                primaryAmountText: "СУММА"
            }
        }

        delegate: HistoryRow {
            required property var model
            width: history.width
            recordId: model.id
            dateText: model.dateText
            typeText: model.typeText
            operationType: model.type
            accountText: model.accountText
            secondaryAccountText: model.secondaryAccountText
            categoryText: model.categoryText
            primaryAmountText: model.primaryAmountText
            secondaryAmountText: model.secondaryAmountText
            descriptionText: model.descriptionText
            busy: page.ledger.commandPending
            onRemoveRequested: (recordId, description) =>
                page.removeOperationRequested(recordId, description)
        }

        footer: Item {
            width: history.width
            height: 100
            RowLayout {
                anchors.fill: parent
                EditorialText {
                    Layout.fillWidth: true
                    text: page.ledger.historyCaption
                    color: DesktopTheme.muted
                    font.family: DesktopTheme.mono
                    font.pixelSize: 11
                }
                ActionButton {
                    visible: page.ledger.historyHasMore || page.ledger.historyLoading
                    text: page.ledger.historyLoading ? "ЗАГРУЗКА…" : "ПОКАЗАТЬ ЕЩЁ"
                    enabled: !page.ledger.historyLoading && page.ledger.historyHasMore
                    onClicked: page.ledger.loadMoreHistory()
                }
            }
        }
    }
}
