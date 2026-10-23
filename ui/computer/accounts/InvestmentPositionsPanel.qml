import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

Rectangle {
    SurfaceShadow { visible: !Appearance.desktop;  }

    id: panel
    signal contextMenuRequested(var position, var sourceItem, real x, real y)
    signal deleteRequested(var position)
    signal operationRequested(var position)
    signal editRequested(var position)
    property bool showEditButton: false

    property var controller
    property bool confirmDeletion: false
    property color panelColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF8")
    property color textColor: "#031528"
    property color mutedColor: (Appearance.desktop ? "#59616a" : "#687483")
    property color lineColor: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    property color errorColor: (Appearance.desktop ? "#b84932" : "#B94F48")

    component PanelButton: StyledButton {
        appTextColor: panel.textColor
        appMutedColor: panel.mutedColor
        appPanelColor: panel.panelColor
        appSoftColor: (Appearance.desktop ? "#f3eddf" : "#FFFFF0")
        appLineColor: panel.lineColor
        appAccentColor: panel.textColor
        appHoverColor: (Appearance.desktop ? "#e9e4d8" : "#E4E8F1")
        appOnAccentColor: panel.panelColor
        appErrorColor: panel.errorColor
    }

    SurfaceShadow { visible: !Appearance.desktop;  }

    color: panelColor
    radius: Appearance.desktop ? 0 : 14
    border.color: lineColor

    EditorialColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.desktop ? 16 : 14
        spacing: 8

        EditorialRowLayout {
            Layout.fillWidth: true
            EditorialLabel {
                Layout.fillWidth: true
                text: "Позиции"
                color: panel.textColor
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            PanelButton {
                text: panel.controller && panel.controller.investmentRefreshing
                      ? "Обновляем…" : "Обновить цены"
                enabled: panel.controller && !panel.controller.investmentRefreshing
                onClicked: panel.controller.refreshInvestmentQuotes()
            }
        }

        EditorialLabel {
            Layout.fillWidth: true; visible: panel.controller && panel.controller.investmentValuationIncomplete
            text: "Оценка капитала неполная: для части позиций нужна котировка, курс или ручная стоимость."
            color: panel.errorColor; wrapMode: Text.WordWrap; font.pixelSize: Appearance.desktop ? 16 : 14
        }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Appearance.desktop ? 8 : 6
            model: panel.controller ? panel.controller.investmentPositions : []
            delegate: Rectangle {
                SurfaceShadow { visible: !Appearance.desktop;  }

                required property var modelData
                required property int index
                width: ListView.view.width
                height: panel.width < 620 ? 144 : 104
                color: index % 2 ? "#FAF9EC" : "transparent"
                radius: Appearance.desktop ? 0 : 8

                GridLayout {
                    columns: panel.width < 620 ? 2 : 3
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.desktop ? 12 : 10
                    anchors.rightMargin: Appearance.desktop ? 8 : 6
                    columnSpacing: Appearance.desktop ? 12 : 10
                    rowSpacing: 8
                    EditorialColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: Appearance.desktop ? 4 : 2
                        EditorialLabel {
                            Layout.fillWidth: true
                            text: modelData.symbol + " · " + modelData.name
                            color: panel.textColor
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        EditorialLabel {
                            Layout.fillWidth: true
                            text: modelData.accountName + " · "
                                  + modelData.quantityText + " " + modelData.quantityUnit
                                  + (modelData.direction === -1 ? " · " + "Продано" : "")
                            color: panel.mutedColor
                            font.pixelSize: Appearance.desktop ? 16 : 14
                            elide: Text.ElideRight
                        }
                    }
                    EditorialColumnLayout {
                        Layout.preferredWidth: panel.width < 620 ? 165 : 190
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: panel.width < 620 ? 165 : 250
                        spacing: Appearance.desktop ? 4 : 2
                        EditorialLabel {
                            Layout.fillWidth: true
                            text: modelData.hasQuote
                                  ? modelData.marketValueText + " " + modelData.currency
                                  : "Цена недоступна"
                            color: panel.textColor
                            horizontalAlignment: Text.AlignRight
                            font.weight: Font.DemiBold
                        }
                        EditorialLabel {
                            Layout.fillWidth: true
                            text: modelData.valuationLabel
                            elide: Text.ElideRight
                            color: panel.mutedColor; horizontalAlignment: Text.AlignRight; font.pixelSize: Appearance.desktop ? 16 : 14
                        }
                        EditorialLabel {
                            Layout.fillWidth: true
                            text: modelData.hasMarketQuote && !modelData.manualValuation
                                  ? modelData.priceText + (modelData.type === 2 ? "%" : modelData.type >= 9 ? " " + "пункт." : " " + modelData.quoteCurrency)
                                    + " · " + modelData.quoteSourceLabel
                                  : modelData.valuationError
                            color: panel.mutedColor; horizontalAlignment: Text.AlignRight; font.pixelSize: Appearance.desktop ? 16 : 14
                            elide: Text.ElideRight
                            ToolTip.visible: hover.hovered && text.length > 0
                            ToolTip.text: text
                            HoverHandler { id: hover }
                        }
                        EditorialLabel {
                            Layout.fillWidth: true
                            text: modelData.manualValuation ? modelData.valuedAtText : modelData.quotedAtText
                            color: panel.mutedColor; horizontalAlignment: Text.AlignRight; font.pixelSize: Appearance.desktop ? 16 : 14
                        }
                    }
                    EditorialRowLayout {
                        Layout.columnSpan: panel.width < 620 ? 2 : 1
                        Layout.fillWidth: panel.width < 620
                        PanelButton { text: "Операция"; onClicked: panel.operationRequested(modelData) }
                        PanelButton { visible: panel.showEditButton; text: "Изменить"; onClicked: panel.editRequested(modelData) }
                        Item { visible: panel.width < 620; Layout.fillWidth: true }
                        PanelButton {
                        text: "×"
                        flat: true
                        destructive: true
                        ToolTip.visible: hovered
                        ToolTip.text: "Удалить позицию"
                        onClicked: {
                            if (panel.confirmDeletion)
                                panel.deleteRequested(modelData);
                            else if (panel.controller)
                                panel.controller.deleteInvestmentPosition(modelData.id);
                        }
                        }
                    }
                }

                MouseArea {
                    id: positionMenuArea
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onPressed: function (mouse) {
                        if (mouse.button === Qt.RightButton)
                            panel.contextMenuRequested(
                                modelData,
                                positionMenuArea,
                                mouse.x,
                                mouse.y
                            );
                    }
                }
            }
            EditorialLabel {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: "Позиций пока нет"
                color: panel.mutedColor
            }
        }
    }
}
