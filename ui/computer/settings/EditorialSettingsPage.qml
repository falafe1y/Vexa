import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common"
import "../dashboard"

EditorialPage {
    id: page
    title: "Настройки."
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
        title: "Шифрование базы"
        description: "Шифрование защищает файл базы. Оно независимо от пароля входа в Vexa."
        EditorialText {
            width: parent.width
            height: implicitHeight
            wrapMode: Text.WordWrap
            text: (databaseProtection.encrypted ? "Локальная база зашифрована." : "Шифрование выключено.")
                  + "\n" + (!appAccess.storeAvailable ? (!appAccess.storeChecked ? "Проверяем системное хранилище…" :
                                                                                   appAccess.storeError || "Системное хранилище недоступно.") :
                                                        "Системное хранилище доступно.")
            color: "#59616a"
        }
        EditorialAction {
            text: databaseProtection.encrypted ? "ОТКЛЮЧИТЬ ШИФРОВАНИЕ" : "ВКЛЮЧИТЬ ШИФРОВАНИЕ"
            enabled: databaseProtection.supported && appAccess.storeChecked && appAccess.storeAvailable
                     && databaseProtection.ready && !databaseProtection.busy
            onClicked: encryption.openConfirmation()
        }
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 2
        title: "Защита паролем"
        description: "Пароль необязателен. Можно использовать от 1 до 1024 символов."
        EditorialText {
            width: parent.width
            height: implicitHeight
            wrapMode: Text.WordWrap
            text: appAccess.enabled ? "Пароль включён. Автоблокировка через 10 минут бездействия." : "Пароль не установлен."
            color: "#59616a"
        }
        Flow {
            width: parent.width
            spacing: 16
            EditorialAction {
                text: appAccess.enabled ? "ИЗМЕНИТЬ ПАРОЛЬ" : "УСТАНОВИТЬ ПАРОЛЬ"
                enabled: appAccess.storeChecked && appAccess.storeAvailable && appAccess.ready && !appAccess.busy
                onClicked: password.openEditor(false)
            }
            EditorialAction {
                visible: appAccess.enabled
                text: "ОТКЛЮЧИТЬ ПАРОЛЬ"
                enabled: appAccess.storeAvailable && !appAccess.busy
                onClicked: password.openEditor(true)
            }
            EditorialAction {
                visible: appAccess.enabled
                text: "ЗАБЛОКИРОВАТЬ"
                onClicked: appAccess.lock()
            }
        }
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 3
        title: "Курсы валют"
        description: page.controller.automaticCurrencyRates ? "Курсы загружаются из ЦБ РФ дважды в сутки. При ошибке используется последний успешный результат." :
                                                              "Автоматические запросы отключены. Используются сохранённые курсы."
        EditorialCheck {
            text: "Обновлять курсы автоматически"
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
                        text: "1 " + modelData.code + " В РУБЛЯХ"
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
            text: "СОХРАНИТЬ КУРСЫ"
            enabled: !page.controller.automaticCurrencyRates
            onClicked: {
                const values = [];
                for (let i = 0; i < rates.count; i++)
                    values.push(Number(rates.itemAt(i).field.text.replace(",", ".")));
                const ok = page.controller.saveManualCurrencyRates(values[0], values[1], values[2], values[3]);
                rateStatus.text = ok ? "Курсы сохранены" : "Введите положительные числовые значения.";
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
        title: "Импорт и экспорт"
        description: "CSV Vexa переносит операции. Банковский импорт поддерживает CSV, XLSX и PDF-выписки Альфы и Сбера."
        Flow {
            width: parent.width
            spacing: 16
            EditorialAction {
                text: "ЭКСПОРТИРОВАТЬ CSV"
                onClicked: page.host.editorialExport()
            }
            EditorialAction {
                text: "ВЫПИСКА БАНКА"
                onClicked: page.host.editorialBankImport()
            }
            EditorialAction {
                text: "ИМПОРТ VEXA"
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
        title: "Резервная копия"
        description: "Переносимая копия счетов, операций, настроек и заметок."
        Flow {
            width: parent.width
            spacing: 16
            EditorialAction {
                text: "СОЗДАТЬ РЕЗЕРВНУЮ КОПИЮ"
                enabled: !databaseProtection.busy
                onClicked: page.host.editorialBackup(false)
            }
            EditorialAction {
                text: "ВОССТАНОВИТЬ"
                enabled: !databaseProtection.busy
                onClicked: page.host.editorialBackup(true)
            }
            EditorialAction {
                text: "АВТОКОПИИ"
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
            text: "Восстановление полностью заменяет текущие данные содержимым копии."
        }
    }
    EditorialSettingRow {
        width: parent.width
        height: implicitHeight
        number: 6
        title: "Удаление данных"
        description: "Удалить счета, операции и остальные пользовательские данные."
        EditorialAction {
            text: "ОЧИСТИТЬ ВСЕ ДАННЫЕ"
            onClicked: page.host.editorialClearData()
        }
    }
}
