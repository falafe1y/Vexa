import QtQuick

MobileInputField {
    validator: RegularExpressionValidator {
        regularExpression: /^\d+([.,]\d{0,2})?$/
    }
    inputMethodHints: Qt.ImhFormattedNumbersOnly

    readonly property string normalizedText: text.replace(/[.,]$/, "").replace(".", ",")

    component Ruler: Item {
        id: ruler

        property int fineStep: 50
        signal amountPicked(string amountText)

        implicitHeight: 46

        function alignToAmount(text: string) {
            const amount = Math.min(ticks.upperLimit, Number(text.replace(",", ".")))
            const index = amount <= ticks.fineLimit ? amount / ruler.fineStep
                : ticks.fineTicks + (amount - ticks.fineLimit) / ticks.coarseStep
            ticks.currentIndex = Math.round(index)
        }

        ListView {
            id: ticks

            readonly property int tickWidth: 14
            readonly property int fineLimit: 5000
            readonly property int upperLimit: 100000
            readonly property int coarseStep: 500
            readonly property int fineTicks: fineLimit / ruler.fineStep
            readonly property var labelLocale: Qt.locale("ru_RU")

            anchors.fill: parent
            clip: true
            orientation: ListView.Horizontal
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapToItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - tickWidth) / 2
            preferredHighlightEnd: preferredHighlightBegin + tickWidth
            highlightMoveDuration: 0
            activeFocusOnTab: true
            keyNavigationEnabled: false
            model: fineTicks + (upperLimit - fineLimit) / coarseStep + 1

            Accessible.role: Accessible.Slider
            Accessible.name: "Шкала суммы"
            Accessible.description: String(amountAt(currentIndex))

            function amountAt(index: int): int {
                return index <= fineTicks ? index * ruler.fineStep
                    : fineLimit + (index - fineTicks) * coarseStep
            }

            function chooseTick(index: int) {
                currentIndex = index
                ruler.amountPicked(String(amountAt(index)))
            }

            onMovementEnded: chooseTick(currentIndex)
            Keys.onLeftPressed: chooseTick(Math.max(0, currentIndex - 1))
            Keys.onRightPressed: chooseTick(Math.min(count - 1, currentIndex + 1))
            Accessible.onIncreaseAction: chooseTick(Math.min(count - 1, currentIndex + 1))
            Accessible.onDecreaseAction: chooseTick(Math.max(0, currentIndex - 1))

            delegate: Item {
                id: tick

                required property int index
                readonly property var view: ListView.view
                readonly property bool major: index % 10 === 0

                width: view?.tickWidth ?? 0
                height: view?.height ?? 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 15 - height / 2
                    width: 1
                    height: tick.major ? 22 : tick.index % 5 === 0 ? 15 : 10
                    color: tick.major ? MobileTheme.ink : MobileTheme.muted
                }

                MobileEditorialText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 29
                    visible: tick.major
                    text: tick.view ? tick.view.amountAt(tick.index).toLocaleString(tick.view.labelLocale, "f", 0) : ""
                    font.family: MobileTheme.mono
                    font.pixelSize: 11
                    color: MobileTheme.muted
                }

                TapHandler {
                    onTapped: tick.view.chooseTick(tick.index)
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 2
            height: 28
            color: MobileTheme.accent
        }
    }
}
