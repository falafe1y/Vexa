import QtQuick
import QtQuick.Layouts
import UI

Item {
    id: page
    required property var ledger
    required property var updates

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 28

        PageHeading {
            Layout.fillWidth: true
            caption: "ЛИЧНЫЙ УЧЁТ / ПАРАМЕТРЫ"
            title: "Настройки."
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: DesktopTheme.ink
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 24

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                EditorialText {
                    text: "Основная валюта"
                    font.pixelSize: 20
                }
                EditorialText {
                    Layout.fillWidth: true
                    text: "В ней показывается общий итог. Валюты счетов и суммы старых операций сохраняются."
                    wrapMode: Text.WordWrap
                    color: DesktopTheme.muted
                }
            }

            SelectField {
                id: currency
                Layout.preferredWidth: 150
                model: page.ledger.currencyCodes
                enabled: !page.ledger.commandPending
                Component.onCompleted: currentIndex = page.ledger.baseCurrencyIndex
                onActivated: page.ledger.setBaseCurrencyCode(currentText)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: DesktopTheme.line
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 24

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                EditorialText {
                    text: "Обновления Vexa"
                    font.pixelSize: 20
                }

                EditorialText {
                    Layout.fillWidth: true
                    color: DesktopTheme.muted
                    wrapMode: Text.WordWrap
                    text: page.updates.updateAvailable
                        ? "Доступна версия " + page.updates.latestVersion
                        : page.updates.checking
                            ? "Проверка обновлений…"
                            : page.updates.errorMessage.length > 0
                                ? "Не удалось проверить обновления"
                                : "Установлена версия " + page.updates.currentVersion
                }
            }

            ActionButton {
                visible: page.updates.updateAvailable
                text: "ПОЛУЧИТЬ ОБНОВЛЕНИЕ ↗"
                onClicked: page.updates.openReleasePage()
            }
        }

        Item { Layout.fillHeight: true }
    }

    Connections {
        target: page.ledger
        function onBaseCurrencyChanged() {
            currency.currentIndex = page.ledger.baseCurrencyIndex
        }
    }
}
