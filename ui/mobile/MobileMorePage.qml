import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: more
    signal navigate(string key)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: layout.implicitHeight + 24
    ColumnLayout {
        id: layout
        width: more.width
        spacing: 0
        Repeater {
            model: [
                {
                    key: "analytics",
                    title: qsTr("Аналитика"),
                    subtitle: qsTr("Доходность и структура капитала")
                },
                {
                    key: "budgets",
                    title: qsTr("Бюджеты"),
                    subtitle: qsTr("Лимиты и расходы")
                },
                {
                    key: "goals",
                    title: qsTr("Цели"),
                    subtitle: qsTr("Накопления и сроки")
                },
                {
                    key: "trajectory",
                    title: qsTr("Траектория"),
                    subtitle: qsTr("Прогноз капитала")
                },
                {
                    key: "projects",
                    title: qsTr("Проекты"),
                    subtitle: qsTr("Доходы и расходы задач")
                },
                {
                    key: "notes",
                    title: qsTr("Заметки"),
                    subtitle: qsTr("Мысли и планы")
                },
                {
                    key: "data",
                    title: qsTr("Импорт и экспорт"),
                    subtitle: qsTr("Данные и резервные копии")
                },
                {
                    key: "settings",
                    title: qsTr("Настройки"),
                    subtitle: qsTr("Валюта, язык и защита")
                }
            ]
            delegate: Button {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 96
                padding: 0
                contentItem: RowLayout {
                    spacing: 16
                    MobileText {
                        font.family: MobileTheme.mono
                        text: String(index + 1).padStart(2, "0")
                        color: MobileTheme.copper
                        font.pixelSize: 12
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        MobileText {
                            font.family: MobileTheme.serif
                            Layout.fillWidth: true
                            text: modelData.title
                            font.pixelSize: 24
                            wrapMode: Text.Wrap
                        }
                        MobileText {
                            font.family: MobileTheme.mono
                            Layout.fillWidth: true
                            text: modelData.subtitle
                            font.pixelSize: 12
                            color: MobileTheme.muted
                            wrapMode: Text.Wrap
                        }
                    }
                    MobileText {
                        font.family: MobileTheme.serif
                        text: "↗"
                        font.pixelSize: 24
                    }
                }
                background: Item {
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: MobileTheme.line
                    }
                }
                onClicked: more.navigate(modelData.key)
            }
        }
    }
}
