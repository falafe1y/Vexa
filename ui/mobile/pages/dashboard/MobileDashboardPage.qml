pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Item {
    id: page

    required property var ledger
    signal createAccountRequested()
    signal editAccountRequested(var data)
    signal editOperationRequested(var data)
    signal operationRequested(int type)
    signal removeAccountRequested(string recordId, string description)
    signal removeOperationRequested(string recordId, string description)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: history

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            model: page.ledger.historyModel

            Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

            header: ColumnLayout {
                width: history.width
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    Layout.leftMargin: MobileTheme.pagePadding
                    Layout.rightMargin: MobileTheme.pagePadding
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MobilePageHeading {
                            Layout.fillWidth: true
                            text: "Мои финансы."
                        }

                        MobileEditorialText {
                            Layout.fillWidth: true
                            text: "Всё время · фильтр в разработке"
                            font.pixelSize: 12
                            color: MobileTheme.muted
                            wrapMode: Text.WordWrap
                        }
                    }

                    MobileBaseCurrencySelector {
                        Layout.minimumWidth: 88
                        Layout.preferredWidth: 88
                        Layout.maximumWidth: 88
                        ledger: page.ledger
                    }
                }

                MobileAssetSummary {
                    Layout.fillWidth: true
                    Layout.leftMargin: MobileTheme.pagePadding
                    Layout.rightMargin: MobileTheme.pagePadding
                    totalText: page.ledger.totalBalanceText
                    accountsCaption: page.ledger.accountsCaption
                }

                MobileAccountsSection {
                    Layout.fillWidth: true
                    Layout.leftMargin: MobileTheme.pagePadding
                    Layout.rightMargin: MobileTheme.pagePadding
                    ledger: page.ledger
                    onCreateRequested: page.createAccountRequested()
                    onEditRequested: data => page.editAccountRequested(data)
                    onRemoveRequested: (recordId, description) => page.removeAccountRequested(recordId, description)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: MobileTheme.pagePadding
                    Layout.rightMargin: MobileTheme.pagePadding
                    spacing: 6

                    MobileEditorialText {
                        Layout.fillWidth: true
                        text: "Журнал операций"
                        font.family: MobileTheme.serif
                        font.pixelSize: 25
                    }

                    MobileEditorialText {
                        Layout.fillWidth: true
                        text: "Поиск в разработке"
                        font.pixelSize: 12
                        color: MobileTheme.muted
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: MobileTheme.ink
                    }
                }
            }

            delegate: MobileHistoryRow {
                required property var model

                width: ListView.view.width
                recordId: model.id
                dateText: model.dateText
                accountId: model.accountId
                secondaryId: model.secondaryId
                amountInput: model.amountInput
                typeText: model.typeText
                operationType: model.type
                accountText: model.accountText
                secondaryAccountText: model.secondaryAccountText
                categoryText: model.categoryText
                primaryAmountText: model.primaryAmountText
                secondaryAmountText: model.secondaryAmountText
                descriptionText: model.descriptionText
                busy: page.ledger.commandPending
                onRemoveRequested: (recordId, description) => page.removeOperationRequested(recordId, description)
                onEditRequested: data => page.editOperationRequested(data)
            }

            footer: ColumnLayout {
                width: history.width
                spacing: 8

                MobileEditorialText {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.leftMargin: MobileTheme.pagePadding
                    Layout.rightMargin: MobileTheme.pagePadding
                    visible: text.length > 0
                    text: page.ledger.historyCaption
                    color: MobileTheme.muted
                }

                MobileActionButton {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.leftMargin: MobileTheme.pagePadding
                    Layout.rightMargin: MobileTheme.pagePadding
                    visible: page.ledger.historyHasMore || page.ledger.historyLoading
                    text: page.ledger.historyLoading ? "ЗАГРУЗКА…" : "ПОКАЗАТЬ ЕЩЁ"
                    enabled: page.ledger.historyHasMore && !page.ledger.historyLoading
                    onClicked: page.ledger.loadMoreHistory()
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 16
                    Layout.leftMargin: MobileTheme.pagePadding
                    Layout.rightMargin: MobileTheme.pagePadding
                    Layout.preferredHeight: planned.implicitHeight + 20
                    radius: 6
                    color: MobileTheme.soft

                    ColumnLayout {
                        id: planned

                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        MobileEditorialText {
                            Layout.fillWidth: true
                            text: "В разработке"
                            font.bold: true
                        }

                        MobileEditorialText {
                            Layout.fillWidth: true
                            text: "Плановые операции, история капитала и структура расходов"
                            color: MobileTheme.muted
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: MobileTheme.line
        }

        MobileActionButton {
            id: addOperation

            Layout.fillWidth: true
            Layout.margins: 8
            Layout.leftMargin: MobileTheme.pagePadding
            Layout.rightMargin: MobileTheme.pagePadding
            text: "+ НОВАЯ ОПЕРАЦИЯ"
            outlined: false
            enabled: page.ledger.canAddOperation
            onClicked: operationMenu.open()

            MobilePopupMenu {
                id: operationMenu

                parent: addOperation
                width: addOperation.width
                y: -height - 6

                MobilePopupMenuItem {
                    text: "Доход"
                    onTriggered: page.operationRequested(0)
                }

                MobilePopupMenuItem {
                    text: "Расход"
                    onTriggered: page.operationRequested(1)
                }

                MobilePopupMenuItem {
                    text: "Перевод"
                    enabled: page.ledger.canTransfer
                    onTriggered: page.operationRequested(2)
                }
            }
        }
    }
}
