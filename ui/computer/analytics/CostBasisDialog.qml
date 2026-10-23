import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../common/EditorialStyle.js" as Appearance

// The purchase price of the coins that have no trade behind them (deposit, bot, transfer).
// The user picks one of two modes; the return of the coin is then counted from that purchase.
EditorialDialog {
    id: dialog
    property var controller
    property string itemId: ""
    property string itemTitle: ""
    property string basisMode: ""
    readonly property bool hasBasis: basisMode.length > 0

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(460, parent.width - 32)
    modal: true
    title: "Цена покупки"
    padding: 24
    background: Rectangle {
        color: (Appearance.desktop ? "#f3eddf" : "#FFFFF8")
        radius: Appearance.desktop ? 0 : 12
        border.color: (Appearance.desktop ? "#bbb5a8" : "#D8D7C7")
    }
    onOpened: { errorLabel.text = ""; priceField.text = ""; dateField.text = ""; manualMode.checked = true }

    contentItem: ColumnLayout {
        spacing: 14

        EditorialLabel {
            Layout.fillWidth: true
            text: dialog.itemTitle
            font.bold: true
        }
        EditorialLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: (Appearance.desktop ? "#59616a" : "#687483")
            text: "Эти монеты попали на счёт не покупкой на бирже, поэтому доходность по ним нужна цена покупки."
        }

        RadioButton {
            id: manualMode
            checked: true
            text: "Указать среднюю цену покупки и дату"
        }
        RadioButton {
            id: connectionMode
            text: "Считать с момента подключения биржи (цена сегодня)"
        }

        EditorialField {
            id: priceField
            visible: manualMode.checked
            Layout.fillWidth: true
            placeholderText: "Цена за 1 монету, $"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        EditorialField {
            id: dateField
            visible: manualMode.checked
            Layout.fillWidth: true
            placeholderText: "Примерная дата покупки, ГГГГ-ММ-ДД"
        }

        EditorialLabel {
            id: errorLabel
            Layout.fillWidth: true
            visible: text.length > 0
            wrapMode: Text.WordWrap
            color: "#b84932"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledButton {
                text: "Отмена"
                onClicked: dialog.close()
            }
            Item { Layout.fillWidth: true }
            StyledButton {
                text: "Сбросить"
                visible: dialog.hasBasis
                onClicked: {
                    if (dialog.controller.clearCryptoCostBasis(dialog.itemId))
                        dialog.close()
                }
            }
            StyledButton {
                text: "Сохранить"
                onClicked: {
                    const price = parseFloat(priceField.text.replace(",", "."));
                    const saved = dialog.controller.setCryptoCostBasis(
                        dialog.itemId,
                        manualMode.checked ? "manual" : "connection",
                        isNaN(price) ? 0 : price,
                        dateField.text.trim());
                    if (saved)
                        dialog.close();
                    else
                        errorLabel.text = "Проверьте цену и дату: цена больше нуля, дата в формате ГГГГ-ММ-ДД и не позже сегодня.";
                }
            }
        }
    }
}
