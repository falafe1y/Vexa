pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import QtQuick.Shapes

ColumnLayout {
    id: historySection

    required property var ledger
    property bool showHeading: true
    property bool showFilters: false
    property bool searchVisible: !showHeading

    signal operationActionsRequested(var data)

    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        Layout.minimumHeight: 50
        visible: historySection.showHeading

        MobileEditorialText {
            Layout.fillWidth: true
            text: "История"
            font.family: MobileTheme.serif
            font.pixelSize: 23
            Accessible.role: Accessible.Heading
        }

        Basic.Button {
            id: searchButton

            implicitWidth: 44
            implicitHeight: 44
            Accessible.name: "Поиск операций"
            onClicked: {
                historySection.searchVisible = !historySection.searchVisible
                if (historySection.searchVisible) searchField.forceActiveFocus()
                else historySection.ledger.historySearchText = ""
            }

            contentItem: Item {
                Shape {
                    anchors.centerIn: parent
                    width: 24
                    height: 24

                    ShapePath {
                        strokeWidth: 1.5
                        strokeColor: MobileTheme.ink
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: "M19 19l-5-5 M16 9a7 7 0 1 1-14 0a7 7 0 1 1 14 0" }
                    }
                }
            }

            background: Rectangle {
                color: searchButton.down ? MobileTheme.soft : "transparent"
                border.width: searchButton.visualFocus ? 1 : 0
                border.color: MobileTheme.accent
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        Layout.bottomMargin: 8
        visible: historySection.searchVisible
        spacing: 8

        MobileInputField {
            id: searchField

            Layout.fillWidth: true
            underlined: true
            text: historySection.ledger.historySearchText
            placeholderText: "Категория, описание или сумма"
            Accessible.name: "Поиск операций"
            onTextEdited: historySection.ledger.historySearchText = text
        }

        MobileActionButton {
            implicitWidth: 36
            implicitHeight: 44
            padding: 0
            flat: true
            text: "×"
            font.family: MobileTheme.sans
            font.pixelSize: 23
            Accessible.name: "Очистить поиск"
            onClicked: {
                historySection.ledger.historySearchText = ""
                searchField.forceActiveFocus()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        Layout.bottomMargin: 8
        visible: historySection.showFilters
        spacing: 6

        Repeater {
            model: [
                {title: "Все", type: -1}, {title: "Расходы", type: 1},
                {title: "Доходы", type: 0}, {title: "Переводы", type: 2}
            ]

            delegate: MobileActionButton {
                required property var modelData

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                implicitHeight: 36
                padding: 2
                cornerRadius: 0
                text: modelData.title
                font.family: MobileTheme.sans
                font.pixelSize: 13
                font.bold: false
                outlined: historySection.ledger.historyOperationType !== modelData.type
                Accessible.selected: historySection.ledger.historyOperationType === modelData.type
                onClicked: historySection.ledger.historyOperationType = modelData.type
            }
        }
    }

    ListView {
        id: history

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: MobileTheme.pagePadding
        Layout.rightMargin: MobileTheme.pagePadding
        clip: true
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        model: historySection.ledger.historyModel

        Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

        section.property: "dateText"
        section.delegate: Item {
            id: dayHeader

            required property string section
            readonly property var day: historySection.ledger.historyDays[section] ?? ({})

            width: history.width
            height: 51
            Accessible.role: Accessible.Heading
            Accessible.name: section

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 7

                MobileEditorialText {
                    text: dayHeader.day.dayText ?? ""
                    font.family: MobileTheme.serif
                    font.pixelSize: 21
                }

                MobileEditorialText {
                    Layout.fillWidth: true
                    text: dayHeader.day.monthText ?? ""
                    font.pixelSize: 12
                    color: MobileTheme.muted
                }

                MobileEditorialText {
                    Layout.maximumWidth: history.width * 0.5
                    text: dayHeader.day.totalText ?? ""
                    font.family: MobileTheme.mono
                    font.pixelSize: 12
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 10
                    horizontalAlignment: Text.AlignRight
                    color: dayHeader.day.negative ? MobileTheme.historyExpense
                        : dayHeader.day.positive ? MobileTheme.historyIncome : MobileTheme.muted
                }
            }
        }

        delegate: MobileHistoryRow {
            required property var model

            width: ListView.view.width
            recordId: model?.id ?? ""
            busy: historySection.ledger.commandPending || historySection.ledger.historyLoading
            onActionsRequested: data => historySection.operationActionsRequested(data)
        }

        onAtYEndChanged: {
            if (atYEnd && count > 0 && historySection.ledger.historyHasMore && !historySection.ledger.historyLoading)
                historySection.ledger.loadMoreHistory()
        }

        footer: ColumnLayout {
            width: history.width
            spacing: 8

            MobileEditorialText {
                objectName: "historyStatusText"

                Layout.fillWidth: true
                Layout.topMargin: 12
                visible: text.length > 0
                text: historySection.ledger.historyCaption
                color: MobileTheme.muted
                wrapMode: Text.Wrap
            }

            MobileActionButton {
                objectName: "historyLoadMoreButton"

                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 12
                visible: historySection.ledger.historyLoadingMore
                    || historySection.ledger.historyHasMore && !historySection.ledger.historyLoading
                text: historySection.ledger.historyLoadingMore ? "Загрузка…" : "Показать ещё"
                cornerRadius: 0
                enabled: historySection.ledger.historyHasMore && !historySection.ledger.historyLoading
                onClicked: historySection.ledger.loadMoreHistory()
            }
        }
    }

    Connections {
        target: historySection.ledger
        function onHistoryFilterChanged() { history.positionViewAtBeginning() }
    }
}
