pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic

Flickable {
    id: strip

    required property var ledger
    property bool compact: false
    property bool showAllAccounts: true
    readonly property string selectedAccountId: ledger.historyAccountId

    implicitHeight: compact ? 73 : 86
    contentWidth: cards.implicitWidth + 2 * MobileTheme.pagePadding
    contentHeight: height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    acceptedButtons: Qt.LeftButton
    pressDelay: 100
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: "История по счёту"

    function revealSelection() {
        let chip = allAccounts
        if (selectedAccountId.length > 0) {
            chip = null
            for (let i = 0; i < accountCards.count; ++i) {
                const item = accountCards.itemAt(i) as MobileAccountChip
                if (item && item.recordId === selectedAccountId) {
                    chip = item
                    break
                }
            }
        }
        if (!chip || !chip.visible || width <= 0)
            return

        const left = cards.x + chip.x - 8
        const right = cards.x + chip.x + chip.width + 8
        if (left < contentX)
            contentX = Math.max(0, left)
        else if (right > contentX + width)
            contentX = Math.min(Math.max(0, contentWidth - width), right - width)
    }

    onSelectedAccountIdChanged: Qt.callLater(revealSelection)
    onContentWidthChanged: Qt.callLater(revealSelection)
    onWidthChanged: Qt.callLater(revealSelection)
    onVisibleChanged: if (visible) Qt.callLater(revealSelection)

    Basic.ScrollIndicator.horizontal: Basic.ScrollIndicator {}

    Keys.onLeftPressed: contentX = Math.max(0, contentX - 150)
    Keys.onRightPressed: contentX = Math.min(Math.max(0, contentWidth - width), contentX + 150)

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const pixel = event.pixelDelta
            const angle = event.angleDelta
            const delta = Math.abs(pixel.x) > Math.abs(pixel.y) ? pixel.x
                : pixel.y || (Math.abs(angle.x) > Math.abs(angle.y) ? angle.x : angle.y) / 2
            const previous = strip.contentX
            strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width,
                                                strip.contentX - delta))
            event.accepted = strip.contentX !== previous
        }
    }

    Row {
        id: cards

        x: MobileTheme.pagePadding
        height: strip.height
        spacing: 20

        MobileAccountChip {
            id: allAccounts

            visible: strip.showAllAccounts
            height: strip.height
            compact: strip.compact
            nameText: "Все счета"
            balanceText: strip.ledger.totalBalanceText
            detailText: "Общий остаток"
            selected: strip.selectedAccountId.length === 0
            onClicked: strip.ledger.historyAccountId = ""
        }

        Repeater {
            id: accountCards

            model: strip.ledger.accountsModel

            delegate: MobileAccountChip {
                id: accountChip

                required property var model

                height: strip.height
                compact: strip.compact
                recordId: model.id
                nameText: model.name
                balanceText: model.primaryText
                credit: model.isCreditCard
                detailText: credit ? "Долг " + model.debtText : model.typeText
                selected: strip.selectedAccountId === model.id
                onClicked: strip.ledger.historyAccountId = accountChip.recordId
            }
        }
    }
}
