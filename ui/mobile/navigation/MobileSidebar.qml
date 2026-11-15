pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Rectangle {
    id: sidebar

    property int currentPage: 0
    property bool updateAvailable: false
    signal pageRequested(int page)

    implicitHeight: 58
    color: MobileTheme.sidebar

    component NavButton: Basic.Button {
        id: tab

        property bool selected: false

        padding: 2
        Accessible.selected: tab.selected

        contentItem: MobileEditorialText {
            text: tab.text
            font.bold: tab.selected
            font.pixelSize: 14
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            color: tab.selected ? MobileTheme.ink : MobileTheme.muted
        }

        background: Rectangle {
            radius: 6
            color: tab.selected || tab.down ? MobileTheme.soft : "transparent"
            border.width: tab.visualFocus ? 1 : 0
            border.color: MobileTheme.accent

            Rectangle {
                visible: tab.selected
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: 18
                height: 2
                color: MobileTheme.accent
            }
        }
    }

    component UnavailableSection: MobilePopupMenuItem {
        enabled: false
        Accessible.name: text + ", в разработке"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: MobileTheme.ink
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 4
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 2

        Repeater {
            model: ["Обзор", "Категории", "Настройки"]

            delegate: NavButton {
                id: section

                required property int index
                required property string modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                text: section.modelData
                selected: sidebar.currentPage === section.index
                Accessible.role: Accessible.PageTab
                Accessible.name: section.index === 2 && sidebar.updateAvailable
                    ? section.text + ", доступно обновление" : section.text
                onClicked: sidebar.pageRequested(section.index)

                Rectangle {
                    visible: section.index === 2 && sidebar.updateAvailable
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    width: 6
                    height: 6
                    radius: 3
                    color: MobileTheme.accent
                }
            }
        }

        NavButton {
            id: more

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            text: "Ещё"
            Accessible.name: "Разделы в разработке"
            onClicked: sections.open()

            MobilePopupMenu {
                id: sections

                parent: more
                x: more.width - width
                y: -height - 6

                MobilePopupMenuItem {
                    text: "В разработке"
                    enabled: false
                }

                UnavailableSection { text: "Цели" }
                UnavailableSection { text: "Заметки" }
                UnavailableSection { text: "Траектория" }
                UnavailableSection { text: "Бюджеты" }
                UnavailableSection { text: "Проекты" }
                UnavailableSection { text: "Аналитика" }
            }
        }
    }
}
