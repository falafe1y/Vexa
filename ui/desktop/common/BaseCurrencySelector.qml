import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Item {
    id: root

    required property var ledger

    property string label: "ВАЛЮТА"
    property color textColor: DesktopTheme.ink
    property color hoverColor: DesktopTheme.accent
    property color backgroundColor: DesktopTheme.paper
    property color borderColor: DesktopTheme.line

    implicitWidth: 72
    implicitHeight: 72

    EditorialText {
        width: parent.width
        height: 24
        text: root.label
        font.family: DesktopTheme.mono
        font.pixelSize: 12
        color: DesktopTheme.muted
    }

    Basic.ComboBox {
        id: selector
        indicator: Item {}
        y: 24
        width: parent.width
        height: 48
        hoverEnabled: true
        enabled: root.enabled && root.ledger.ready && !root.ledger.commandPending

        model: root.ledger.currencyCodes
        currentIndex: root.ledger.baseCurrencyIndex
        onActivated: index => root.ledger.setBaseCurrencyCode(root.ledger.currencyCodes[index])

        font.family: DesktopTheme.sans
        font.bold: true
        font.pixelSize: 16

        background: Rectangle {
            color: root.backgroundColor
            border.width: 1
            border.color: root.borderColor
        }

        contentItem: Text {
            text: selector.displayText
            font: selector.font
            color: selector.enabled && selector.hovered ? root.hoverColor : root.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        delegate: Basic.ItemDelegate {
            id: option

            required property int index
            required property var modelData

            width: selector.width - 2
            height: 30
            hoverEnabled: true

            contentItem: Text {
                text: option.modelData
                font.family: DesktopTheme.sans
                font.pixelSize: 16
                font.bold: selector.currentIndex === option.index
                color: option.enabled && option.hovered ? root.hoverColor : root.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: root.backgroundColor
            }
        }

        popup: Basic.Popup {
            y: selector.height - 1
            width: selector.width
            padding: 1

            background: Rectangle {
                color: root.backgroundColor
                border.width: 1
                border.color: root.borderColor
            }

            contentItem: ListView {
                implicitHeight: contentHeight
                model: selector.delegateModel
                currentIndex: selector.highlightedIndex
                clip: true
            }
        }
    }
}
