pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: page

    required property var ledger
    required property bool landscape
    signal createAccountRequested()
    signal editAccountRequested(var data)
    signal operationRequested(int type)
    signal editOperationRequested(var data)
    signal removeAccountRequested(string recordId, string description)
    signal removeOperationRequested(string recordId, string description)

    readonly property int pagePadding: width < 520 ? 16 : width <= 950 ? 24 : 32
    readonly property int columnPadding: width < 850 ? 14 : 22
    readonly property real contentWidth: Math.max(0, width - 2 * pagePadding)
    readonly property real leftColumnWidth: Math.round(contentWidth * 0.6) - columnPadding
    readonly property real rightColumnWidth: contentWidth - leftColumnWidth - 2 * columnPadding - 1

    spacing: 0

    component Rule: Rectangle {
        color: MobileTheme.ink
    }

    component DevelopmentPanel: ColumnLayout {
        id: panel

        required property string number
        required property string title
        required property string caption
        property int cardHeight: 132

        spacing: 5

        TabletSectionHeading {
            Layout.fillWidth: true
            landscape: true
            title: panel.title
            number: panel.number
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: panel.cardHeight
            radius: 8
            color: "#eee8dc"
            border.width: 1
            border.color: MobileTheme.line

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                MobileEditorialText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "В разработке"
                    font.family: MobileTheme.serif
                    font.italic: true
                    font.pixelSize: page.width < 760 ? 21 : 28
                    color: MobileTheme.muted
                }

                MobileEditorialText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: panel.caption
                    font.family: MobileTheme.mono
                    font.pixelSize: 12
                    color: MobileTheme.muted
                }
            }
        }
    }

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
            spacing: 0

            // The inline header grows when switching layouts or receiving the first accounts.
            onHeightChanged: Qt.callLater(history.positionViewAtBeginning)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 18
                Layout.leftMargin: page.pagePadding
                Layout.rightMargin: page.pagePadding
                spacing: 0

                TabletPageHeader {
                    Layout.fillWidth: true
                    landscape: page.landscape
                    title: "Мои финансы."
                    actions: [
                        ColumnLayout {
                            Layout.alignment: Qt.AlignBottom
                            Layout.preferredWidth: page.landscape && page.width > 900 ? 144 : 108
                            visible: page.width >= 600
                            spacing: 3

                            MobileEditorialText {
                                text: "ПЕРИОД"
                                visible: page.landscape
                                font.family: MobileTheme.mono
                                font.pixelSize: 11
                                color: MobileTheme.muted
                            }

                            MobileEditorialText { text: "Всё время" }

                            MobileEditorialText {
                                text: "Фильтр в разработке"
                                font.pixelSize: 11
                                color: MobileTheme.muted
                            }
                        },
                        MobileBaseCurrencySelector {
                            Layout.preferredWidth: 86
                            Layout.maximumWidth: 96
                            ledger: page.ledger
                        }
                    ]
                }

                TabletAssetSummary {
                    Layout.fillWidth: true
                    Layout.topMargin: page.landscape ? 0 : 12
                    landscape: page.landscape
                    totalText: page.ledger.totalBalanceText
                    accountsCaption: page.ledger.accountsCaption
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: page.landscape ? 0 : 18
                    spacing: 0

                    TabletAccountsSection {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: page.landscape ? page.leftColumnWidth : page.contentWidth
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: page.landscape ? 9 : 0
                        Layout.rightMargin: page.landscape ? page.columnPadding : 0
                        Layout.bottomMargin: page.landscape ? 13 : 0
                        landscape: page.landscape
                        ledger: page.ledger
                        onCreateRequested: page.createAccountRequested()
                        onEditRequested: data => page.editAccountRequested(data)
                        onRemoveRequested: (recordId, description) => page.removeAccountRequested(recordId, description)
                    }

                    Rule {
                        Layout.fillHeight: true
                        implicitWidth: 1
                        visible: page.landscape
                    }

                    DevelopmentPanel {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: page.rightColumnWidth
                        Layout.alignment: Qt.AlignTop
                        Layout.leftMargin: page.columnPadding
                        Layout.topMargin: 9
                        Layout.bottomMargin: 13
                        visible: page.landscape
                        number: "02."
                        title: "На горизонте"
                        caption: "Плановые операции"
                        cardHeight: 174
                    }
                }

                Rule {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    visible: page.landscape
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: page.landscape
                    spacing: 0

                    DevelopmentPanel {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: page.leftColumnWidth
                        Layout.topMargin: 9
                        Layout.rightMargin: page.columnPadding
                        Layout.bottomMargin: 13
                        number: "03."
                        title: "История капитала"
                        caption: "Динамика капитала"
                    }

                    Rule {
                        Layout.fillHeight: true
                        implicitWidth: 1
                    }

                    DevelopmentPanel {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: page.rightColumnWidth
                        Layout.topMargin: 9
                        Layout.leftMargin: page.columnPadding
                        Layout.bottomMargin: 13
                        number: "04."
                        title: "Структура расходов"
                        caption: "Распределение расходов"
                    }
                }

                Rule {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    visible: page.landscape
                }

                TabletSectionHeading {
                    Layout.fillWidth: true
                    Layout.topMargin: page.landscape ? 6 : 16
                    Layout.bottomMargin: page.landscape ? 6 : 0
                    landscape: page.landscape
                    number: "05."
                    title: page.landscape ? "Реестр операций" : "Журнал операций"
                    actions: [
                        MobileEditorialText {
                            visible: page.landscape
                            text: "Поиск в разработке"
                            color: MobileTheme.muted
                            font.pixelSize: 12
                        },
                        TabletOperationButton {
                            landscape: true
                            ledger: page.ledger
                            visible: page.landscape
                            onOperationRequested: type => page.operationRequested(type)
                        }
                    ]
                }

                MobileEditorialText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 9
                    visible: !page.landscape
                    text: "Поиск в разработке"
                    color: MobileTheme.muted
                    font.pixelSize: 12
                }

                Rule {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    visible: !page.landscape
                }

                TabletHistoryRow {
                    Layout.fillWidth: true
                    visible: page.landscape
                    landscape: true
                }
            }
        }

        delegate: Item {
            id: entry

            required property var model

            width: history.width
            height: operationRow.height

            TabletHistoryRow {
                id: operationRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: page.pagePadding
                landscape: page.landscape
                operation: entry.model
                busy: page.ledger.commandPending
                onEditRequested: data => page.editOperationRequested(data)
                onRemoveRequested: (recordId, description) => page.removeOperationRequested(recordId, description)
            }
        }

        footer: ColumnLayout {
            width: history.width
            spacing: 0

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: page.pagePadding
                Layout.topMargin: 10
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true

                    MobileEditorialText {
                        Layout.fillWidth: true
                        text: page.ledger.historyCaption
                        font.family: MobileTheme.mono
                        font.pixelSize: 12
                        color: MobileTheme.muted
                    }

                    MobileActionButton {
                        visible: page.ledger.historyHasMore || page.ledger.historyLoading
                        enabled: page.ledger.historyHasMore && !page.ledger.historyLoading
                        text: page.ledger.historyLoading ? "ЗАГРУЗКА…" : "ПОКАЗАТЬ ЕЩЁ"
                        onClicked: page.ledger.loadMoreHistory()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: later.implicitHeight + 20
                    visible: !page.landscape
                    radius: 4
                    color: MobileTheme.soft

                    ColumnLayout {
                        id: later

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12
                        spacing: 5

                        MobileEditorialText {
                            text: "В разработке"
                            font.bold: true
                        }

                        MobileEditorialText {
                            Layout.fillWidth: true
                            text: "Плановые операции, история капитала и структура расходов"
                            color: MobileTheme.muted
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                    }
                }
            }
        }
    }

    Rule {
        Layout.fillWidth: true
        implicitHeight: 1
        visible: !page.landscape
        color: MobileTheme.line
    }

    TabletOperationButton {
        Layout.fillWidth: true
        Layout.leftMargin: page.pagePadding
        Layout.rightMargin: page.pagePadding
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: !page.landscape
        landscape: false
        ledger: page.ledger
        onOperationRequested: type => page.operationRequested(type)
    }
}
