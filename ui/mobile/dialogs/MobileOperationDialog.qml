pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import QtQuick.Shapes

MobileFormDialog {
    id: dialog

    required property var ledger
    property int operationType: 0
    property var editData: null
    property string operationDateText: ""

    readonly property bool isTransfer: operationType === 2
    readonly property var dateLocale: Qt.locale("ru_RU")
    readonly property string dateFormat: "dd.MM.yyyy"
    readonly property string currencyCode: accountBox.currentIndex >= 0
        ? ledger.accountsModel.row(accountBox.currentIndex).currencyCode ?? "" : ""

    title: (editData ? "Редактировать: " : "") +
        (operationType === 0 ? "Доход" : isTransfer ? "Перевод" : "Расход")
    showTitle: !sheetStyle
    busy: ledger.commandPending
    onClosed: editData = null

    function openFor(type, accountId = "") {
        editData = null
        operationType = type
        errorText = ""
        amountField.text = ""
        descriptionField.text = ""
        operationDateText = ledger.currentDateText()
        dateField.text = operationDateText
        const selectedIndex = accountBox.indexOfValue(accountId)
        accountBox.currentIndex = selectedIndex >= 0 ? selectedIndex : accountBox.count > 0 ? 0 : -1
        receiverBox.currentIndex = receiverBox.count > 1
            ? (accountBox.currentIndex === 0 ? 1 : 0) : -1
        categoryBox.currentIndex = categoryBox.count > 0 ? 0 : -1
        ruler.alignToAmount(amountField.normalizedText)
        open()
    }

    function openForEdit(data) {
        editData = data
        operationType = data.type
        errorText = ""
        accountBox.currentIndex = accountBox.indexOfValue(data.accountId)
        if (isTransfer)
            receiverBox.currentIndex = receiverBox.indexOfValue(data.secondaryId)
        else
            categoryBox.currentIndex = categoryBox.indexOfValue(data.secondaryId)
        amountField.text = data.amountInput
        operationDateText = data.dateText
        dateField.text = operationDateText
        descriptionField.text = data.descriptionText
        ruler.alignToAmount(amountField.normalizedText)
        open()
    }

    function selectType(type) {
        if (operationType === type)
            return

        operationType = type
        errorText = ""
        if (isTransfer && receiverBox.currentIndex === accountBox.currentIndex)
            receiverBox.currentIndex = receiverBox.count > 1
                ? (accountBox.currentIndex === 0 ? 1 : 0) : -1
        if (!isTransfer) {
            categoryBox.currentIndex = editData && editData.type === type
                ? categoryBox.indexOfValue(editData.secondaryId)
                : categoryBox.count > 0 ? 0 : -1
        }
        ruler.alignToAmount(amountField.normalizedText)
    }

    Connections {
        target: dialog.ledger

        function onCommandFinished(commandName, id) {
            if (dialog.visible && (commandName === "income"
                                  || commandName === "expense"
                                  || commandName === "transfer"
                                  || commandName === "updateOperation"))
                dialog.close()
        }

        function onErrorOccurred(message) {
            if (dialog.visible)
                dialog.errorText = message
        }
    }

    component FieldLabel: MobileEditorialText {
        Layout.fillWidth: true
        font.pixelSize: dialog.sheetStyle ? 13 : 14
        color: dialog.sheetStyle ? MobileTheme.muted : MobileTheme.ink
    }

    component CalendarButton: MobileActionButton {
        flat: false
        cornerRadius: 0
        font.family: MobileTheme.serif
        font.pixelSize: 24
        font.bold: false
        Layout.preferredWidth: 44
        implicitWidth: 44
        implicitHeight: 44
        padding: 0
    }

    body: ColumnLayout {
        width: parent.width
        enabled: !dialog.busy
        spacing: dialog.sheetStyle ? 10 : 8

        RowLayout {
            Layout.fillWidth: true
            visible: dialog.sheetStyle
            spacing: 0

            Repeater {
                model: [
                    { title: "Расход", type: 1 },
                    { title: "Перевод", type: 2 },
                    { title: "Доход", type: 0 }
                ]

                delegate: MobileActionButton {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    implicitHeight: 44
                    padding: 2
                    cornerRadius: 0
                    text: modelData.title
                    font.family: MobileTheme.sans
                    font.pixelSize: 14
                    font.bold: false
                    outlined: dialog.operationType !== modelData.type
                    enabled: modelData.type !== 2 || dialog.ledger.canTransfer
                    Accessible.role: Accessible.PageTab
                    Accessible.selected: dialog.operationType === modelData.type
                    onClicked: dialog.selectType(modelData.type)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: dialog.sheetStyle ? (dialog.isTransfer ? 3 : 2) : 1
            columnSpacing: 7
            rowSpacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: dialog.sheetStyle ? 4 : 8

                FieldLabel {
                    id: accountLabel
                    text: dialog.isTransfer ? (dialog.sheetStyle ? "Откуда" : "Счёт отправителя") : "Счёт"
                }

                MobileSelectField {
                    id: accountBox

                    Layout.fillWidth: true
                    underlined: dialog.sheetStyle
                    Accessible.name: accountLabel.text
                    model: dialog.ledger.accountsModel
                    textRole: "name"
                    valueRole: "id"
                }
            }

            Basic.Button {
                id: swap

                Layout.alignment: Qt.AlignBottom
                Layout.preferredWidth: 44
                implicitWidth: 44
                implicitHeight: 44
                visible: dialog.sheetStyle && dialog.isTransfer
                enabled: accountBox.currentIndex >= 0 && receiverBox.currentIndex >= 0
                padding: 0
                text: "⇄"
                Accessible.name: "Поменять счета местами"

                contentItem: MobileEditorialText {
                    text: swap.text
                    font.pixelSize: 22
                    horizontalAlignment: Text.AlignHCenter
                }

                background: Rectangle {
                    color: swap.down ? MobileTheme.soft : "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: swap.visualFocus ? 2 : 1
                        color: swap.visualFocus ? MobileTheme.accent : MobileTheme.ink
                    }
                }

                onClicked: {
                    const previous = accountBox.currentIndex
                    accountBox.currentIndex = receiverBox.currentIndex
                    receiverBox.currentIndex = previous
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                visible: dialog.isTransfer
                spacing: dialog.sheetStyle ? 4 : 8

                FieldLabel {
                    id: receiverLabel
                    text: dialog.sheetStyle ? "Куда" : "Счёт получателя"
                }

                MobileSelectField {
                    id: receiverBox

                    Layout.fillWidth: true
                    underlined: dialog.sheetStyle
                    Accessible.name: receiverLabel.text
                    model: dialog.ledger.accountsModel
                    textRole: "name"
                    valueRole: "id"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                visible: !dialog.isTransfer
                spacing: dialog.sheetStyle ? 4 : 8

                FieldLabel { text: "Категория" }

                MobileSelectField {
                    id: categoryBox

                    Layout.fillWidth: true
                    underlined: dialog.sheetStyle
                    Accessible.name: "Категория"
                    model: dialog.operationType === 0
                        ? dialog.ledger.incomeCategoriesModel
                        : dialog.ledger.expenseCategoriesModel
                    textRole: "name"
                    valueRole: "id"
                }
            }
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: !dialog.isTransfer && categoryBox.count === 0
            text: "Добавьте категорию на вкладке «Категории»."
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            color: MobileTheme.muted
            font.pixelSize: 12
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: dialog.sheetStyle
            spacing: 4

            FieldLabel { text: "Дата" }

            Basic.Button {
                id: dateButton

                Layout.fillWidth: true
                implicitHeight: 43
                padding: 0
                text: dialog.operationDateText
                Accessible.name: "Дата операции, " + text
                onClicked: calendar.open()

                contentItem: RowLayout {
                    MobileEditorialText {
                        Layout.fillWidth: true
                        text: dateButton.text
                        font.pixelSize: 16
                    }

                    Shape {
                        Layout.rightMargin: 2
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        ShapePath {
                            strokeWidth: 1.5
                            strokeColor: MobileTheme.ink
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: "M4 6h16v14H4z M8 4v4 M16 4v4 M4 10h16 M8 14h2 M14 14h2" }
                        }
                    }
                }

                background: Rectangle {
                    color: dateButton.down ? MobileTheme.soft : "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: dateButton.visualFocus ? 2 : 1
                        color: dateButton.visualFocus ? MobileTheme.accent : MobileTheme.ink
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: dialog.sheetStyle ? 4 : 8

            FieldLabel {
                id: amountLabel
                text: dialog.sheetStyle ? "Сумма" : dialog.isTransfer
                    ? "Сумма списания в валюте отправителя" : "Сумма в валюте счёта"
                wrapMode: Text.WordWrap
            }

            MobileAmountField {
                id: amountField

                Layout.fillWidth: true
                implicitHeight: dialog.sheetStyle ? 48 : MobileTheme.touchSize
                underlined: dialog.sheetStyle
                leftPadding: dialog.sheetStyle ? currencyMark.implicitWidth + 10 : padding
                rightPadding: leftPadding
                topPadding: dialog.sheetStyle ? 0 : padding
                bottomPadding: topPadding
                font.family: dialog.sheetStyle ? MobileTheme.serif : MobileTheme.sans
                font.pixelSize: dialog.sheetStyle ? 34 : 16
                horizontalAlignment: dialog.sheetStyle ? TextInput.AlignHCenter : TextInput.AlignLeft
                Accessible.name: amountLabel.text + (dialog.currencyCode ? ", " + dialog.currencyCode : "")
                placeholderText: dialog.sheetStyle ? "0" : "Например, 1500,50"

                onTextEdited: ruler.alignToAmount(amountField.normalizedText)

                MobileEditorialText {
                    id: currencyMark

                    visible: dialog.sheetStyle
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({ RUB: "₽", USD: "$", EUR: "€", CNY: "¥" })[dialog.currencyCode] ?? ""
                    font.pixelSize: 18
                    color: MobileTheme.muted
                }
            }

            MobileAmountField.Ruler {
                id: ruler

                Layout.fillWidth: true
                visible: dialog.sheetStyle
                fineStep: dialog.operationType === 1 ? 50 : 500
                onAmountPicked: amount => amountField.text = amount
            }
        }

        MobileEditorialText {
            Layout.fillWidth: true
            visible: !dialog.sheetStyle && dialog.isTransfer
            text: "Сумма зачисления рассчитывается по фиксированному курсу."
            font.pixelSize: 12
            color: MobileTheme.muted
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: dialog.sheetStyle ? 4 : 8

            FieldLabel { text: "Описание" }

            MobileInputField {
                id: descriptionField

                Layout.fillWidth: true
                underlined: dialog.sheetStyle
                Accessible.name: "Описание"
                maximumLength: 50
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: !dialog.sheetStyle
            spacing: 8

            FieldLabel { text: "Дата" }

            MobileInputField {
                id: dateField

                Layout.fillWidth: true
                Accessible.name: "Дата"
                placeholderText: "ДД.ММ.ГГГГ"
                inputMask: "00.00.0000"
                inputMethodHints: Qt.ImhDigitsOnly
            }
        }
    }

    footer: MobileDialogActions {
        errorText: dialog.errorText
        busy: dialog.busy
        sheetStyle: dialog.sheetStyle
        submitColor: dialog.sheetStyle ? (dialog.isTransfer ? MobileTheme.ink
            : dialog.operationType === 0 ? MobileTheme.income : MobileTheme.accent) : MobileTheme.ink
        submitText: dialog.sheetStyle
            ? (dialog.editData ? "Сохранить" : dialog.isTransfer ? "Записать перевод"
                : dialog.operationType === 0 ? "Записать доход" : "Записать расход")
            : (dialog.editData ? "СОХРАНИТЬ" : "ДОБАВИТЬ")
        canSubmit: accountBox.currentIndex >= 0
            && (dialog.isTransfer ? receiverBox.currentIndex >= 0 : categoryBox.currentIndex >= 0)

        onCancelled: dialog.close()

        onSubmitted: {
            dialog.errorText = ""
            const date = dialog.sheetStyle ? dialog.operationDateText : dateField.text
            if (dialog.editData) {
                dialog.ledger.updateOperation(dialog.editData.id, dialog.operationType,
                    accountBox.currentValue,
                    dialog.isTransfer ? receiverBox.currentValue : categoryBox.currentValue,
                    amountField.normalizedText, date, descriptionField.text)
            } else if (dialog.operationType === 0) {
                dialog.ledger.addIncome(accountBox.currentValue, categoryBox.currentValue,
                    amountField.normalizedText, date, descriptionField.text)
            } else if (dialog.operationType === 1) {
                dialog.ledger.addExpense(accountBox.currentValue, categoryBox.currentValue,
                    amountField.normalizedText, date, descriptionField.text)
            } else {
                dialog.ledger.transfer(accountBox.currentValue, receiverBox.currentValue,
                    amountField.normalizedText, date, descriptionField.text)
            }
        }
    }

    MobileFormDialog {
        id: calendar

        property int monthIndex: 0

        parent: dialog.parent
        z: dialog.z + 1
        sheetStyle: true
        sheetDimColor: "#61031528"
        title: "Дата операции"

        Basic.CalendarModel {
            id: months

            from: "0001-01-01"
            to: "9999-12-31"
        }

        function chooseDate(dateText: string) {
            dialog.operationDateText = dateText
            close()
        }

        onAboutToShow: {
            if (InputMethod.visible)
                InputMethod.hide()
            const date = dialog.operationDateText.split(".")
            monthIndex = months.indexOf(Number(date[2]), Number(date[1]) - 1)
        }

        body: ColumnLayout {
            width: parent.width
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 10

                CalendarButton {
                    text: "‹"
                    Accessible.name: "Предыдущий месяц"
                    enabled: calendar.monthIndex > 0
                    onClicked: --calendar.monthIndex
                }

                MobileEditorialText {
                    Layout.fillWidth: true
                    text: month.title.charAt(0).toUpperCase() + month.title.slice(1)
                    font.family: MobileTheme.serif
                    font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter
                }

                CalendarButton {
                    text: "›"
                    Accessible.name: "Следующий месяц"
                    enabled: calendar.monthIndex + 1 < months.count
                    onClicked: ++calendar.monthIndex
                }
            }

            Basic.DayOfWeekRow {
                Layout.fillWidth: true
                locale: dialog.dateLocale
                spacing: 0

                delegate: MobileEditorialText {
                    required property string shortName

                    text: shortName
                    font.family: MobileTheme.mono
                    font.pixelSize: 11
                    color: MobileTheme.muted
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: MobileTheme.line
            }

            Basic.MonthGrid {
                id: month

                Layout.fillWidth: true
                Layout.preferredHeight: 234
                month: months.monthAt(calendar.monthIndex)
                year: months.yearAt(calendar.monthIndex)
                locale: dialog.dateLocale
                spacing: 0

                delegate: Basic.Button {
                    id: day

                    required property var model
                    readonly property string dateText: Qt.formatDate(model.date, dialog.dateFormat)
                    readonly property bool selected: dateText === dialog.operationDateText

                    opacity: model.month === month.month ? 1 : 0
                    enabled: model.month === month.month
                    text: String(model.day)
                    padding: 0
                    Accessible.name: dateText
                    Accessible.selected: selected
                    onClicked: calendar.chooseDate(dateText)

                    contentItem: MobileEditorialText {
                        text: day.text
                        font.family: MobileTheme.mono
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        color: day.selected ? MobileTheme.sidebar
                            : day.model.today ? MobileTheme.accent : MobileTheme.ink
                    }

                    background: Rectangle {
                        color: day.selected ? MobileTheme.ink : day.down ? MobileTheme.soft : "transparent"
                        border.width: day.visualFocus ? 1 : 0
                        border.color: MobileTheme.accent
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: MobileTheme.line
            }

            MobileActionButton {
                Layout.fillWidth: true
                flat: true
                text: "Сегодня"
                actionColor: MobileTheme.accent
                onClicked: calendar.chooseDate(dialog.ledger.currentDateText())
            }
        }
    }
}
