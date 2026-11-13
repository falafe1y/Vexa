import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI
import QtQuick.Controls.Basic as Basic

// Pure QML presentation: all money and operation fields are provided by LedgerInterface.
// Unavailable reports never derive monetary totals from other displayed values.
Flickable {
    id: page
    required property var ledger
    signal createAccountRequested()
    signal editAccountRequested(var data)
    signal editOperationRequested(var data)
    signal operationRequested(int type)
    signal removeAccountRequested(string recordId, string description)
    signal removeOperationRequested(string recordId, string description)

    readonly property bool narrow: width <= 650
    readonly property bool small: width <= 950 && !narrow
    readonly property bool medium: width <= 1300
    readonly property bool compact: height <= 1000 && !narrow
    readonly property int pad: narrow ? 20 : small ? 24 : medium ? 32 : 48
    readonly property int inset: small ? 16 : 24
    readonly property int topInset: compact ? 16 : 24
    readonly property int mainWidth: width - pad * 2
    readonly property int leftWidth: narrow ? mainWidth : Math.round(mainWidth * (small ? .58 : .59596) / 4) * 4

    clip: true
    contentWidth: width
    contentHeight: paper.height + 96
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    component Rule: Rectangle { height: 1; color: DesktopTheme.ink }
    component Mono: EditorialText { font.family: DesktopTheme.mono; font.pixelSize: 12; color: DesktopTheme.muted }
    component Serif: EditorialText { font.family: DesktopTheme.serif; font.pixelSize: page.small ? 32 : 36; font.letterSpacing: -.5 }
    component DevelopmentPanel: Rectangle {
        property string symbol: "○"
        property string caption: ""
        color: "#eee8dc"
        radius: 8
        border.width: 1
        border.color: DesktopTheme.line
        opacity: 0.78
        Column {
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 6
            EditorialText {
                width: parent.width; height: 40
                text: symbol
                color: DesktopTheme.muted
                font.family: DesktopTheme.sans; font.pixelSize: 34
                horizontalAlignment: Text.AlignHCenter
            }
            EditorialText {
                width: parent.width; height: 40
                text: "В разработке"
                font.family: "Gelasio"; font.italic: true; font.pixelSize: 28
                color: DesktopTheme.muted
                horizontalAlignment: Text.AlignHCenter
            }
            Mono {
                width: parent.width; height: 24
                text: caption
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    component Heading: Item {
        property string number: ""
        property string title: ""
        property string note: ""
        property string action: ""
        signal activated()
        height: 32
        Mono { width: page.small ? 24 : 32; height: parent.height; text: parent.number; color: DesktopTheme.accent }
        EditorialText {
            x: page.small ? 24 : 32
            height: parent.height
            width: Math.max(0, parent.width - x - (headerAction.visible ? headerAction.width + 8 : headerNote.visible ? headerNote.width + 8 : 0))
            text: parent.title; font.bold: true
            font.pixelSize: page.small ? 13 : page.medium && !page.narrow ? 15 : 16
        }
        ActionButton {
            id: headerAction
            visible: text.length > 0
            anchors.right: parent.right
            text: parent.action
            outlined: false
            implicitHeight: 32
            onClicked: parent.activated()
        }
        Mono { id: headerNote; visible: text.length > 0; anchors.right: parent.right; height: 32; text: parent.note }
    }

    Item {
        id: paper
        x: page.pad; y: 24; width: page.mainWidth
        height: historyFooter.y + historyFooter.height

        Item {
            id: masthead
            width: parent.width
            height: page.narrow ? 196 : page.compact ? 104 : 128
            Serif {
                y: page.narrow ? 12 : masthead.height - height - 8
                width: page.narrow ? parent.width : Math.max(0, controls.x - 16)
                height: page.narrow ? 64 : page.compact ? 88 : 96
                text: "Мои финансы."
                font.italic: true; font.letterSpacing: -2
                font.pixelSize: page.narrow ? 52 : page.small ? 56 : page.compact ? 72 : page.medium ? 64 : 80
                fontSizeMode: Text.Fit; minimumPixelSize: 28
            }
            Item {
                id: controls
                anchors.right: parent.right
                y: page.narrow ? 92 : masthead.height - height - 8
                height: 80
                width: page.narrow ? parent.width : page.small ? 440 : page.medium ? 496 : 560

                Item {
                    id: periodPlaceholder
                    x: 0
                    width: controls.width - currencyBox.width - 16
                    height: 72
                    anchors.verticalCenter: parent.verticalCenter
                    Mono { height: 24; text: "ПЕРИОД" }
                    EditorialText {
                        y: 24; height: 32; text: "Все время"
                        color: DesktopTheme.muted; font.pixelSize: 16
                    }
                    Mono {
                        y: 48; height: 20; width: parent.width
                        text: "В разработке"; font.pixelSize: 10
                    }
                    Rectangle {
                        y: 70; height: 1; width: parent.width
                        color: DesktopTheme.line
                    }
                }

                BaseCurrencySelector {
                    id: currencyBox
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 72
                    ledger: page.ledger
                }
            }
            Rule { y: parent.height; width: parent.width }
        }

        AssetSummary {
            id: summary

            y: masthead.height
            width: parent.width

            height: implicitHeight

            totalText: page.ledger.totalBalanceText
            accountsCaption: page.ledger.accountsCaption

            narrow: page.narrow
            small: page.small
            medium: page.medium
            compact: page.compact
        }

        Item {
            id: firstRow
            y: summary.y + summary.height; width: parent.width
            height: page.narrow ? 544 : page.compact ? 240 : 264
            Rule { y: parent.height - 1; width: parent.width }
            Item {
                id: accountsPanel
                width: page.leftWidth - (page.narrow ? 0 : page.inset)
                height: page.narrow ? 280 : parent.height
                Heading {
                    id: accountsHead
                    y: page.topInset; width: parent.width
                    number: "01."; title: "СЧЕТА / ФИАТ"
                    action: "+ ДОБАВИТЬ СЧЕТ"
                    onActivated: page.createAccountRequested()
                }
                ListView {
                    id: accountList
                    y: accountsHead.y + accountsHead.height + 8
                    width: parent.width; height: page.compact ? 152 : 168
                    clip: true; reuseItems: true
                    model: page.ledger.accountsModel
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }
                    delegate: Item {
                        id: accountRow
                        required property var model
                        required property int index
                        width: accountList.width; height: 56
                        Mono {
                            x: 0; height: parent.height; width: page.small ? 20 : 32
                            text: (accountRow.index + 1).toString().padStart(2, "0")
                        }
                        EditorialText {
                            x: page.small ? 28 : 48; y: 4
                            width: Math.max(0, accountAmount.x - x - 8); height: 24
                            text: accountRow.model.name
                            font.bold: true; font.pixelSize: page.small ? 14 : 16
                        }
                        EditorialText {
                            x: page.small ? 28 : 48; y: 28
                            width: Math.max(0, accountAmount.x - x - 8); height: 20
                            text: accountRow.model.typeText
                            color: DesktopTheme.muted; font.pixelSize: page.small ? 12 : 14
                        }
                        Serif {
                            id: accountAmount
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            y: 0; width: Math.min(190, accountRow.width * .36); height: 56
                            text: accountRow.model.primaryText
                            font.pixelSize: page.small ? 22 : page.medium ? 24 : 28
                            horizontalAlignment: Text.AlignRight
                            fontSizeMode: Text.Fit; minimumPixelSize: 14
                        }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            enabled: !page.ledger.commandPending
                            onTapped: (point, button) =>
                                accountContextMenu.openAt(point.position.x, point.position.y)
                        }
                        ContextActionMenu {
                            id: accountContextMenu
                            editEnabled: !page.ledger.commandPending
                            onEditRequested: page.editAccountRequested({
                                id: accountRow.model.id,
                                name: accountRow.model.name,
                                type: accountRow.model.type,
                                currencyCode: accountRow.model.currencyCode,
                                openingInput: accountRow.model.openingInput,
                                limitInput: accountRow.model.limitInput
                            })
                            removeEnabled: !page.ledger.commandPending
                            onRemoveRequested: page.removeAccountRequested(
                                accountRow.model.id, accountRow.model.name)
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: DesktopTheme.line }
                    }
                }
                Mono { visible: accountList.count === 0; y: accountList.y; width: parent.width; height: accountList.height; text: "Счетов пока нет. Добавьте первый счет."; horizontalAlignment: Text.AlignHCenter }
            }
            Item {
                id: horizon
                x: page.narrow ? 0 : page.leftWidth
                y: page.narrow ? accountsPanel.height : 0
                width: parent.width - x
                height: page.narrow ? 264 : parent.height
                Rectangle { visible: !page.narrow; width: 1; height: parent.height; color: DesktopTheme.ink }
                Rule { visible: page.narrow; width: parent.width }
                Item {
                    x: page.narrow ? 0 : page.inset; y: page.topInset
                    width: parent.width - x; height: parent.height - y
                    Heading { width: parent.width; number: "02."; title: "НА ГОРИЗОНТЕ" }
                    DevelopmentPanel {
                        y: 48; width: parent.width
                        height: Math.max(130, parent.height - 64)
                        symbol: "▢"
                        caption: "Плановые операции скоро появятся"
                    }
                }
            }
        }

        Item {
            id: analyticsPanel
            y: firstRow.y + firstRow.height; width: parent.width
            height: page.narrow ? 528 : page.compact ? 224 : 264
            Rule { y: parent.height - 1; width: parent.width }
            Item {
                width: page.leftWidth - (page.narrow ? 0 : page.inset)
                y: page.topInset; height: page.narrow ? 264 : analyticsPanel.height - y
                Heading { width: parent.width; number: "03."; title: "ИСТОРИЯ КАПИТАЛА" }
                DevelopmentPanel {
                    y: 48; width: parent.width
                    height: page.compact ? 152 : 168
                    symbol: "▥"
                    caption: "Динамика капитала скоро появится"
                }
            }
            Item {
                x: page.narrow ? 0 : page.leftWidth
                y: page.narrow ? 264 : 0
                width: parent.width - x; height: page.narrow ? 264 : parent.height
                Rectangle { visible: !page.narrow; width: 1; height: parent.height; color: DesktopTheme.ink }
                Rule { visible: page.narrow; width: parent.width }
                Item {
                    x: page.narrow ? 0 : page.inset; y: page.topInset
                    width: parent.width - x; height: parent.height - y
                    Heading { width: parent.width; number: "04."; title: "СТРУКТУРА РАСХОДОВ" }
                    DevelopmentPanel {
                        y: 48; width: parent.width
                        height: page.compact ? 152 : 168
                        symbol: "◉"
                        caption: "Структура расходов скоро появится"
                    }
                }
            }
        }

        Item {
            id: historyToolbar
            y: analyticsPanel.y + analyticsPanel.height
            width: parent.width; height: page.narrow ? 104 : 56
            Heading {
                y: page.narrow ? 8 : 12
                width: page.narrow ? parent.width : Math.max(0, searchField.x - 16)
                number: "05."; title: "РЕЕСТР ОПЕРАЦИЙ"
            }
            TextField {
                id: searchField
                verticalAlignment: TextInput.AlignVCenter
                topPadding: 0
                bottomPadding: 0
                x: page.narrow ? 0 : newOperation.x - width - 16
                anchors.verticalCenter: parent.verticalCenter
                width: page.narrow ? Math.max(0, newOperation.x - 16) : page.small ? 184 : 224
                height: 40
                enabled: false
                placeholderText: "Поиск · В разработке"
                color: DesktopTheme.muted
                placeholderTextColor: DesktopTheme.muted
                font.family: DesktopTheme.sans; font.pixelSize: 14
                background: Item { Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: DesktopTheme.line } }
            }
            ActionButton {
                id: newOperation
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                y: page.narrow ? 56 : 12
                implicitWidth: 160
                text: "+ НОВАЯ ОПЕРАЦИЯ"
                enabled: page.ledger.canAddOperation
                onClicked: operationMenu.open()
                PopupMenu {
                    id: operationMenu
                    x: parent.width - width
                    y: parent.height - 1
                    width: Math.max(parent.width, 192)

                    PopupMenuItem {
                        text: "Доход"
                        onTriggered: page.operationRequested(0)
                    }
                    PopupMenuItem {
                        text: "Расход"
                        onTriggered: page.operationRequested(1)
                    }
                    PopupMenuItem {
                        text: "Перевод"
                        enabled: page.ledger.canTransfer
                        onTriggered: page.operationRequested(2)
                    }
                }
            }
        }
        HistoryRow {
            id: historyHead
            y: historyToolbar.y + historyToolbar.height
            width: parent.width
            heading: true
            dateText: "ДАТА"; typeText: "ТИП"; accountText: "СЧЕТ"; categoryText: "КАТЕГОРИЯ"; primaryAmountText: "СУММА"
        }
        ListView {
            id: history
            y: historyHead.y + historyHead.height
            width: parent.width
            height: contentHeight
            interactive: false
            clip: false
            model: page.ledger.historyModel
            reuseItems: true
            delegate: HistoryRow {
                required property var model
                width: history.width
                recordId: model.id
                dateText: model.dateText
                accountId: model.accountId; secondaryId: model.secondaryId
                amountInput: model.amountInput
                typeText: model.typeText; operationType: model.type
                accountText: model.accountText; secondaryAccountText: model.secondaryAccountText
                categoryText: model.categoryText
                primaryAmountText: model.primaryAmountText; secondaryAmountText: model.secondaryAmountText
                descriptionText: model.descriptionText
                busy: page.ledger.commandPending
                onRemoveRequested: (recordId, description) => page.removeOperationRequested(recordId, description)
                onEditRequested: data => page.editOperationRequested(data)
            }
        }
        Item {
            id: historyFooter
            y: history.y + history.height
            width: parent.width; height: 64
            Mono { height: parent.height; width: parent.width - moreButton.width; text: page.ledger.historyCaption }
            ActionButton {
                id: moreButton
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                visible: page.ledger.historyHasMore || page.ledger.historyLoading
                text: page.ledger.historyLoading ? "ЗАГРУЗКА…" : "ПОКАЗАТЬ ЕЩЕ"
                enabled: !page.ledger.historyLoading && page.ledger.historyHasMore
                onClicked: page.ledger.loadMoreHistory()
            }
        }
    }
}
