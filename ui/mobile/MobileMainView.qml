pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ApplicationWindow {
    id: window

    enum Page { Dashboard, Categories, Accounts, More, Analytics, Settings, History }

    required property var ledger
    required property var updates

    width: 390
    height: 844
    visibility: Qt.platform.os === "android" || Qt.platform.os === "ios"
        ? Window.Maximized : Window.Windowed
    title: "Vexa"
    color: MobileTheme.paper
    font.family: MobileTheme.sans
    font.pixelSize: 16
    palette.window: MobileTheme.paper
    palette.base: MobileTheme.sidebar
    palette.text: MobileTheme.ink
    palette.windowText: MobileTheme.ink
    palette.buttonText: MobileTheme.ink
    palette.button: MobileTheme.paper
    palette.highlight: MobileTheme.ink
    palette.highlightedText: MobileTheme.sidebar

    function openHistory(accountId, categoryId) {
        pages.currentIndex = MobileMainView.History
        ledger.filterHistory(accountId, categoryId)
    }

    function showDashboard() {
        pages.currentIndex = MobileMainView.Dashboard
        ledger.resetHistoryFilters()
    }

    function openOperationActions(data) {
        operationActions.operation = data
        operationActions.open()
    }

    MobileAccountDialog {
        id: accountDialog
        parent: window.contentItem
        ledger: window.ledger
        sheetStyle: true
    }

    MobileCategoryDialog {
        id: categoryDialog
        parent: window.contentItem
        ledger: window.ledger
        sheetStyle: true
    }

    MobileOperationDialog {
        id: operationDialog
        parent: window.contentItem
        ledger: window.ledger
        sheetStyle: true
    }

    MobileRemovalDialog {
        id: removalDialog
        parent: window.contentItem
        ledger: window.ledger
        sheetStyle: true
    }

    MobileFormDialog {
        id: operationActions

        property var operation: null

        parent: window.contentItem
        sheetStyle: true
        title: "Операция"
        onClosed: operation = null

        body: ColumnLayout {
            width: parent.width
            spacing: 8

            MobileEditorialText {
                Layout.fillWidth: true
                text: operationActions.operation?.summary ?? ""
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: MobileTheme.muted
            }

            MobileActionButton {
                Layout.fillWidth: true
                cornerRadius: 0
                text: "Редактировать"
                enabled: !window.ledger.commandPending
                onClicked: {
                    const operation = operationActions.operation
                    operationActions.close()
                    operationDialog.openForEdit(operation)
                }
            }

            MobileActionButton {
                Layout.fillWidth: true
                cornerRadius: 0
                text: "Удалить"
                danger: true
                enabled: !window.ledger.commandPending
                onClicked: {
                    const operation = operationActions.operation
                    operationActions.close()
                    removalDialog.ask("removeOperation", operation.id, operation.summary)
                }
            }
        }
    }

    MobileFormDialog {
        id: assetDialog

        parent: window.contentItem
        sheetStyle: true

        body: MobileEditorialText {
            width: parent.width
            bottomPadding: 4
            text: "В разработке"
            color: MobileTheme.muted
        }
    }

    component MoreLink: Basic.Button {
        id: link

        property string detail: "›"

        Layout.fillWidth: true
        implicitHeight: 46
        padding: 0

        contentItem: RowLayout {
            MobileEditorialText {
                Layout.fillWidth: true
                text: link.text
                font.pixelSize: 16
            }

            MobileEditorialText {
                text: link.detail
                font.family: MobileTheme.mono
                font.pixelSize: 11
                color: MobileTheme.muted
            }
        }

        background: Rectangle {
            color: link.down ? MobileTheme.soft : "transparent"
            border.width: link.visualFocus ? 1 : 0
            border.color: MobileTheme.accent

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: MobileTheme.line
            }
        }
    }

    ColumnLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, MobileTheme.phonePageWidth)
        spacing: 0

        StackLayout {
            id: pages

            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: MobileMainView.Dashboard

            MobileDashboardPage {
                ledger: window.ledger
                onAccountsRequested: pages.currentIndex = MobileMainView.Accounts
                onAssetRequested: name => {
                    assetDialog.title = name
                    assetDialog.open()
                }
                onOperationActionsRequested: data => window.openOperationActions(data)
            }

            MobileCategoriesPage {
                ledger: window.ledger
                onHistoryRequested: categoryId => window.openHistory("", categoryId)
                onEditRequested: data => categoryDialog.openForEdit(data)
                onRemoveRequested: (recordId, description) =>
                    removalDialog.ask("removeCategory", recordId, description)
            }

            MobileAccountsSection {
                ledger: window.ledger
                onHistoryRequested: accountId => window.openHistory(accountId, "")
                onEditRequested: data => accountDialog.openForEdit(data)
                onRemoveRequested: (recordId, description) =>
                    removalDialog.ask("removeAccount", recordId, description)
            }

            Flickable {
                id: more

                clip: true
                contentWidth: width
                contentHeight: links.implicitHeight + 2 * MobileTheme.pagePadding
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: links

                    x: MobileTheme.pagePadding
                    y: 13
                    width: more.width - 2 * x
                    spacing: 0

                    MobilePageHeading {
                        Layout.fillWidth: true
                        documentStyle: true
                        text: "Ещё"
                    }

                    MoreLink {
                        text: "Аналитика"
                        onClicked: pages.currentIndex = MobileMainView.Analytics
                    }

                    MoreLink {
                        text: "История операций"
                        onClicked: window.openHistory("", "")
                    }

                    MoreLink {
                        text: "Настройки"
                        detail: window.updates.updateAvailable ? "Доступно обновление" : "›"
                        onClicked: pages.currentIndex = MobileMainView.Settings
                    }

                    MoreLink {
                        text: "Криптовалюта"
                        detail: "В разработке"
                        onClicked: {
                            assetDialog.title = text
                            assetDialog.open()
                        }
                    }

                    MoreLink {
                        text: "Инвестиции"
                        detail: "В разработке"
                        onClicked: {
                            assetDialog.title = text
                            assetDialog.open()
                        }
                    }
                }
            }

            MobileAnalyticsPage {
                ledger: window.ledger
                onBackRequested: pages.currentIndex = MobileMainView.More
            }

            MobileSettingsPage {
                ledger: window.ledger
                updates: window.updates
                onBackRequested: pages.currentIndex = MobileMainView.More
            }

            MobileHistoryPage {
                ledger: window.ledger
                onOperationActionsRequested: data => window.openOperationActions(data)
                onBackRequested: window.showDashboard()
            }
        }

        MobileSidebar {
            Layout.fillWidth: true
            phoneLayout: true
            currentPage: pages.currentIndex === MobileMainView.History
                ? MobileMainView.Dashboard : Math.min(pages.currentIndex, MobileMainView.More)
            updateAvailable: window.updates.updateAvailable
            addEnabled: pages.currentIndex === MobileMainView.Dashboard || pages.currentIndex === MobileMainView.History
                ? window.ledger.canAddOperation
                : (pages.currentIndex === MobileMainView.Categories
                   || pages.currentIndex === MobileMainView.Accounts)
                  && window.ledger.ready && !window.ledger.commandPending

            onPageRequested: page => {
                if (page === MobileMainView.Dashboard)
                    window.showDashboard()
                else
                    pages.currentIndex = page
            }
            onAddRequested: {
                switch (pages.currentIndex) {
                case MobileMainView.Dashboard:
                case MobileMainView.History:
                    operationDialog.openFor(1, window.ledger.historyAccountId)
                    break
                case MobileMainView.Categories:
                    categoryDialog.openFor(1)
                    break
                case MobileMainView.Accounts:
                    accountDialog.open()
                    break
                }
            }
        }
    }
}
