import QtQuick
import QtQuick.Layouts
import UI

ColumnLayout {
    id: section
    required property var ledger
    signal createRequested()
    signal removeRequested(string recordId, string description)
    spacing: 16

    RowLayout {
        Layout.fillWidth: true
        EditorialText {
            Layout.fillWidth: true
            text: "01. / СЧЕТА"
            font.family: DesktopTheme.mono
            font.pixelSize: 12
            font.bold: true
        }
        ActionButton {
            text: "+ ДОБАВИТЬ СЧЁТ"
            outlined: false
            enabled: section.ledger.ready && !section.ledger.commandPending
            onClicked: section.createRequested()
        }
    }

    EditorialText {
        Layout.fillWidth: true
        visible: section.ledger.accountsModel.count === 0
        text: "Пока здесь пусто. Добавьте первый счёт."
        color: DesktopTheme.muted
    }

    GridLayout {
        Layout.fillWidth: true
        columns: width >= 1100 ? 3 : 2
        columnSpacing: 16
        rowSpacing: 16

        Repeater {
            model: section.ledger.accountsModel
            delegate: AccountCard {
                required property var model
                Layout.fillWidth: true
                Layout.minimumWidth: 240
                Layout.preferredWidth: 300
                recordId: model.id
                nameText: model.name
                typeText: model.typeText
                currencyCode: model.currencyCode
                primaryLabel: model.primaryLabel
                primaryText: model.primaryText
                credit: model.isCreditCard
                debtText: model.debtText
                limitText: model.creditLimitText
                busy: section.ledger.commandPending
                onRemoveRequested: (recordId, description) =>
                    section.removeRequested(recordId, description)
            }
        }
    }
}
