import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../dashboard"

EditorialPage {
    id: page
    title: qsTr("Настройки.")
    DatabaseEncryptionSettings {
        id: encryption
        visible: false
        width: 0
        height: 0
    }
    PasswordSettings {
        id: password
        visible: false
        width: 0
        height: 0
    }
    AutoBackupSettings {
        id: autoBackupSettings
        visible: false
        width: 0
        height: 0
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 1
        title: qsTr("Шифрование базы")
        description: qsTr("Шифрование защищает файл базы. Оно независимо от пароля входа в Vexa.")
        EditorialText {
            width: parent.width
            height: implicitHeight
            wrapMode: Text.WordWrap
            text: (databaseProtection.encrypted ? qsTr("Локальная база зашифрована.") : qsTr("Шифрование выключено."))
                  + "\n" + (!appAccess.storeAvailable ? (!appAccess.storeChecked ? qsTr(
                                                                                       "Проверяем системное хранилище…") :
                                                                                   appAccess.storeError || qsTr(
                                                                                       "Системное хранилище недоступно.")) :
                                                        qsTr("Системное хранилище доступно."))
            color: "#59616a"
        }
        EditorialAction {
            text: databaseProtection.encrypted ? qsTr("ОТКЛЮЧИТЬ ШИФРОВАНИЕ") : qsTr("ВКЛЮЧИТЬ ШИФРОВАНИЕ")
            enabled: databaseProtection.supported && appAccess.storeChecked && appAccess.storeAvailable
                     && databaseProtection.ready && !databaseProtection.busy
            onClicked: encryption.openConfirmation()
        }
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 2
        title: qsTr("Защита паролем")
        description: qsTr("Пароль необязателен. Можно использовать от 1 до 1024 символов.")
        EditorialText {
            width: parent.width
            height: implicitHeight
            wrapMode: Text.WordWrap
            text: appAccess.enabled ? qsTr("Пароль включён. Автоблокировка через 10 минут бездействия.") : qsTr(
                                          "Пароль не установлен.")
            color: "#59616a"
        }
        Flow {
            width: parent.width
            spacing: 16
            EditorialAction {
                text: appAccess.enabled ? qsTr("ИЗМЕНИТЬ ПАРОЛЬ") : qsTr("УСТАНОВИТЬ ПАРОЛЬ")
                enabled: appAccess.storeChecked && appAccess.storeAvailable && appAccess.ready && !appAccess.busy
                onClicked: password.openEditor(false)
            }
            EditorialAction {
                visible: appAccess.enabled
                text: qsTr("ОТКЛЮЧИТЬ ПАРОЛЬ")
                enabled: appAccess.storeAvailable && !appAccess.busy
                onClicked: password.openEditor(true)
            }
            EditorialAction {
                visible: appAccess.enabled
                text: qsTr("ЗАБЛОКИРОВАТЬ")
                onClicked: appAccess.lock()
            }
        }
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 3
        title: qsTr("Курсы валют")
        description: page.controller.automaticCurrencyRates ? qsTr(
                                                                  "Курсы загружаются из ЦБ РФ дважды в сутки. При ошибке используется последний успешный результат.") :
                                                              qsTr("Автоматические запросы отключены. Используются сохранённые курсы.")
        EditorialCheck {
            text: qsTr("Обновлять курсы автоматически")
            checked: page.controller.automaticCurrencyRates
            onToggled: page.controller.automaticCurrencyRates = checked
        }
        GridLayout {
            width: parent.width
            columns: page.host.width <= 1150 ? 2 : 4
            columnSpacing: 24
            rowSpacing: 16
            Repeater {
                id: rates
                model: [
                    {
                        code: "RUB",
                        value: page.controller.manualRubToRubRate
                    },
                    {
                        code: "USD",
                        value: page.controller.manualUsdToRubRate
                    },
                    {
                        code: "EUR",
                        value: page.controller.manualEurToRubRate
                    },
                    {
                        code: "CNY",
                        value: page.controller.manualCnyToRubRate
                    }
                ]
                ColumnLayout {
                    required property var modelData
                    property alias field: field
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    EditorialText {
                        text: "1 " + modelData.code + qsTr(" В РУБЛЯХ")
                        font.family: "Cousine"
                        font.pixelSize: 12
                        color: "#59616a"
                    }
                    EditorialField {
                        id: field
                        Layout.fillWidth: true
                        enabled: !page.controller.automaticCurrencyRates
                        text: Number(modelData.value).toLocaleString(Qt.locale("ru_RU"), "f", 4)
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        validator: DoubleValidator {
                            bottom: .000001
                            top: 999999999
                            decimals: 6
                            locale: "ru_RU"
                        }
                    }
                }
            }
        }
        EditorialText {
            width: parent.width
            height: implicitHeight
            visible: page.controller.automaticCurrencyRates
            text: page.controller.currentCurrencyRates.map(function (r) {
                return "1 " + r.code + " = " + Number(r.rate).toLocaleString(Qt.locale("ru_RU"), "f", 4) + " ₽";
            }).join("  ·  ")
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            color: "#59616a"
        }
        EditorialAction {
            text: qsTr("СОХРАНИТЬ КУРСЫ")
            enabled: !page.controller.automaticCurrencyRates
            onClicked: {
                const values = [];
                for (let i = 0; i < rates.count; i++)
                    values.push(Number(rates.itemAt(i).field.text.replace(",", ".")));
                const ok = page.controller.saveManualCurrencyRates(values[0], values[1], values[2], values[3]);
                rateStatus.text = ok ? qsTr("Курсы сохранены") : qsTr("Введите положительные числовые значения.");
            }
        }
        EditorialText {
            id: rateStatus
            width: parent.width
            height: text ? 24 : 0
            font.pixelSize: 14
            color: "#59616a"
        }
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 4
        title: qsTr("Импорт и экспорт")
        description: qsTr(
                         "CSV Vexa переносит операции. Банковский импорт поддерживает CSV, XLSX и PDF-выписки Альфы и Сбера.")
        Flow {
            width: parent.width
            spacing: 16
            EditorialAction {
                text: qsTr("ЭКСПОРТИРОВАТЬ CSV")
                onClicked: page.host.editorialExport()
            }
            EditorialAction {
                text: qsTr("ВЫПИСКА БАНКА")
                onClicked: page.host.editorialBankImport()
            }
            EditorialAction {
                text: qsTr("ИМПОРТ VEXA")
                onClicked: page.host.editorialImport()
            }
        }
        EditorialText {
            width: parent.width
            height: text ? implicitHeight : 0
            wrapMode: Text.WordWrap
            text: page.host.csvStatus
            font.pixelSize: 14
            color: page.host.csvStatusOk ? "#2e5947" : "#b84932"
        }
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 5
        title: qsTr("Резервная копия")
        description: qsTr("Переносимая копия счетов, операций, настроек и заметок.")
        Flow {
            width: parent.width
            spacing: 16
            EditorialAction {
                text: qsTr("СОЗДАТЬ РЕЗЕРВНУЮ КОПИЮ")
                enabled: !databaseProtection.busy
                onClicked: page.host.editorialBackup(false)
            }
            EditorialAction {
                text: qsTr("ВОССТАНОВИТЬ")
                enabled: !databaseProtection.busy
                onClicked: page.host.editorialBackup(true)
            }
            EditorialAction {
                text: qsTr("АВТОКОПИИ")
                enabled: !databaseProtection.busy
                onClicked: autoBackupSettings.openSettings()
            }
        }
        EditorialText {
            width: parent.width
            height: implicitHeight
            wrapMode: Text.WordWrap
            font.pixelSize: 14
            color: "#59616a"
            text: qsTr("Восстановление полностью заменяет текущие данные содержимым копии.")
        }
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 6
        title: qsTr("Удаление данных")
        description: qsTr("Удалить счета, операции и остальные пользовательские данные.")
        EditorialAction {
            text: qsTr("ОЧИСТИТЬ ВСЕ ДАННЫЕ")
            onClicked: page.host.editorialClearData()
        }
    }
}
