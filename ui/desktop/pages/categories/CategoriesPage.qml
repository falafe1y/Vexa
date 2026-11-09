import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Item {
    id: page
    required property var ledger
    signal createRequested()
    signal removeRequested(string recordId, string description)

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 24
        clip: true
        model: page.ledger.categoriesModel
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        header: Column {
            width: list.width
            spacing: 24
            PageHeading {
                width: parent.width
                caption: "ЛИЧНЫЙ УЧЁТ / СПРАВОЧНИК"
                title: "Категории."
            }
            RowLayout {
                width: parent.width
                EditorialText {
                    Layout.fillWidth: true
                    text: "КАТЕГОРИИ ДОХОДОВ И РАСХОДОВ"
                    font.family: DesktopTheme.mono
                    font.pixelSize: 11
                }
                ActionButton {
                    text: "+ КАТЕГОРИЯ"
                    enabled: page.ledger.ready && !page.ledger.commandPending
                    onClicked: page.createRequested()
                }
            }
            Rectangle {
                width: parent.width
                height: 1
                color: DesktopTheme.ink
            }
            EditorialText {
                visible: list.count === 0
                width: parent.width
                text: "Пока нет категорий. Добавьте первую."
                color: DesktopTheme.muted
            }
        }

        delegate: Item {
            id: category
            required property var model
            width: list.width
            height: 72

            RowLayout {
                anchors.fill: parent
                spacing: 24
                EditorialText {
                    Layout.fillWidth: true
                    text: category.model.name
                    font.pixelSize: 17
                }
                EditorialText {
                    Layout.preferredWidth: 80
                    text: category.model.typeText
                    color: DesktopTheme.muted
                    font.family: DesktopTheme.mono
                    font.pixelSize: 12
                }
                ActionButton {
                    text: "УБРАТЬ"
                    outlined: false
                    danger: true
                    enabled: !page.ledger.commandPending
                    onClicked: page.removeRequested(category.model.id, category.model.name)
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: DesktopTheme.line
            }
        }
    }
}
