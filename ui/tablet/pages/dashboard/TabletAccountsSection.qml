pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

ColumnLayout {
    id: section

    required property bool landscape
    required property var ledger
    signal createRequested()
    signal editRequested(var data)
    signal removeRequested(string recordId, string description)

    spacing: landscape ? 5 : 9

    TabletSectionHeading {
        Layout.fillWidth: true
        landscape: section.landscape
        number: "01."
        title: section.landscape ? "Счета / Фиат" : "Счета"
        actions: [
            MobileActionButton {
                text: section.landscape ? "+ ДОБАВИТЬ СЧЁТ" : "+ СЧЁТ"
                Accessible.name: "Добавить счёт"
                enabled: section.ledger.ready && !section.ledger.commandPending
                onClicked: section.createRequested()
            }
        ]
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        visible: !section.landscape
        color: MobileTheme.ink
    }

    ListView {
        id: accounts

        readonly property int cardsPerRow: width >= 540 ? 3 : 2

        Layout.fillWidth: true
        Layout.preferredHeight: section.landscape ? 174 : 150
        visible: section.landscape || count > 0
        clip: true
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        orientation: section.landscape ? ListView.Vertical : ListView.Horizontal
        flickableDirection: section.landscape ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        spacing: section.landscape ? 0 : 10
        model: section.ledger.accountsModel
        interactive: section.landscape ? count > 3 : count > cardsPerRow

        Basic.ScrollIndicator.horizontal: Basic.ScrollIndicator {}
        Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

        delegate: TabletAccountCard {
            id: card

            required property var model
            required property int index

            width: section.landscape ? accounts.width - 4
                : (accounts.width - (accounts.cardsPerRow - 1) * accounts.spacing) / accounts.cardsPerRow
            height: section.landscape ? 58 : accounts.height
            landscape: section.landscape
            account: card.model
            position: card.index
            busy: section.ledger.commandPending
            onEditRequested: data => section.editRequested(data)
            onRemoveRequested: (recordId, description) => section.removeRequested(recordId, description)
        }

        MobileEditorialText {
            width: accounts.width
            height: accounts.height
            visible: section.ledger.ready && accounts.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: "Счетов пока нет. Добавьте первый счёт."
            color: MobileTheme.muted
        }
    }

    MobileEditorialText {
        Layout.fillWidth: true
        visible: !section.landscape && section.ledger.ready && accounts.count === 0
        text: "Счетов пока нет."
        color: MobileTheme.muted
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !section.landscape && accounts.count > 0

        MobileEditorialText {
            Layout.fillWidth: true
            text: section.ledger.accountsCaption
            font.family: MobileTheme.mono
            font.pixelSize: 12
            color: MobileTheme.muted
        }

        MobileEditorialText {
            visible: accounts.count > accounts.cardsPerRow
            text: "Листайте счета →"
            font.pixelSize: 12
            color: MobileTheme.muted
        }
    }
}
