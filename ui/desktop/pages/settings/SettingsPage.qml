
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Flickable {
    id: page

    required property var ledger
    required property var updates
    readonly property bool narrow: width <= 650
    readonly property bool small: width <= 950 && !narrow
    readonly property bool medium: width <= 1300
    readonly property bool compact: height <= 1000 && !narrow
    readonly property int pad: narrow ? 20 : small ? 24 : medium ? 32 : 48
    readonly property int mainWidth: width - pad * 2

    clip: true
    contentWidth: width
    contentHeight: Math.max(height, paper.y + paper.height + 24)
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOff
    }

    component Mono: EditorialText {
        font.family: DesktopTheme.mono
        font.pixelSize: 12
        color: DesktopTheme.muted
    }

    Item {
        id: paper

        x: page.pad
        y: 24
        width: page.mainWidth
        height: masthead.height + 24 + content.implicitHeight

        // Шапка — геометрия как на Dashboard
        Item {
            id: masthead

            width: parent.width
            height: page.narrow ? 196 : page.compact ? 104 : 128

            EditorialText {
                id: heading

                y: page.narrow ? 12 : masthead.height - height - 8

                width: parent.width
                height: page.narrow ? 64 : page.compact ? 88 : 96

                text: "Настройки."

                font.family: DesktopTheme.serif
                font.italic: true
                font.letterSpacing: -2
                font.pixelSize: page.narrow ? 52
                    : page.small ? 56
                    : page.compact ? 72
                    : page.medium ? 64 : 80

                fontSizeMode: Text.Fit
                minimumPixelSize: 28

                color: DesktopTheme.ink

                Item {
                    id: currencyBox
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 72
                    height: 72
                    Mono {
                        height: 24
                        text: "ВАЛЮТА"
                    }
                    ComboBox {
                        id: currencySelector
                        y: 24
                        width: parent.width
                        height: 48
                        hoverEnabled: true
                        model: page.ledger.currencyCodes
                        currentIndex: page.ledger.baseCurrencyIndex
                        enabled: page.ledger.ready && !page.ledger.commandPending
                        onActivated: index => page.ledger.setBaseCurrencyCode(page.ledger.currencyCodes[index])
                        font.family: DesktopTheme.sans
                        font.bold: true
                        font.pixelSize: 16

                        background: Rectangle {
                            color: DesktopTheme.paper
                            border.width: 1
                            border.color: DesktopTheme.line
                        }

                        // закрытый список
                        contentItem: Text {
                            text: currencySelector.displayText
                            font: currencySelector.font
                            color: currencySelector.hovered ? DesktopTheme.accent : DesktopTheme.ink
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            // leftPadding: 6
                        }

                        // элементы раскрытого списка
                        delegate: ItemDelegate {
                            id: currencyDelegate

                            required property int index
                            required property var modelData

                            width: currencySelector.width
                            height: 30

                            hoverEnabled: true

                            contentItem: Text {
                                text: currencyDelegate.modelData

                                font.family: DesktopTheme.sans
                                font.pixelSize: 16
                                font.bold: currencySelector.currentIndex === currencyDelegate.index

                                color: currencyDelegate.hovered ? DesktopTheme.accent : DesktopTheme.ink

                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: DesktopTheme.paper
                            }
                        }

                        // Раскрытый список
                        popup: Popup {
                            y: currencySelector.height - 1
                            width: currencySelector.width
                            padding: 1

                            background: Rectangle {
                                color: DesktopTheme.paper
                                border.width: 1
                                border.color: DesktopTheme.line
                            }

                            contentItem: ListView {
                                implicitHeight: contentHeight
                                model: currencySelector.delegateModel
                                currentIndex: currencySelector.highlightedIndex
                                clip: true
                            }
                        }
                    }
                }
            }

            // разделитель
            Rectangle {
                y: parent.height
                width: parent.width
                height: 1
                color: DesktopTheme.ink
            }
        }

        // содержимое настроек
        ColumnLayout {
            id: content
            y: masthead.height + 24
            width: parent.width
            spacing: 24
        }
    }

    Connections {
        target: page.ledger
    }
}
