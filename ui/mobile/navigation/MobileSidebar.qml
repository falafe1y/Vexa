pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import QtQuick.Shapes

Rectangle {
    id: sidebar

    property int currentPage: 0
    property bool updateAvailable: false
    property bool phoneLayout: false
    property bool addEnabled: false
    signal pageRequested(int page)
    signal addRequested()

    implicitHeight: phoneLayout ? 64 : 58
    color: phoneLayout ? MobileTheme.ink : MobileTheme.sidebar

    component PhoneTab: Basic.Button {
        id: phoneTab

        required property int pageIndex
        required property string iconPath

        readonly property bool selected: sidebar.currentPage === pageIndex
        readonly property bool more: pageIndex === 3

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 1
        padding: 0

        Accessible.role: Accessible.PageTab
        Accessible.selected: selected
        Accessible.name: more && sidebar.updateAvailable
            ? text + ", доступно обновление" : text

        contentItem: Item {
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 2

                Shape {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 24
                    height: 24

                    ShapePath {
                        strokeWidth: 1.5
                        strokeColor: phoneTab.selected ? MobileTheme.ink : MobileTheme.muted
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: phoneTab.iconPath }
                    }
                }

                MobileEditorialText {
                    width: parent.width
                    text: phoneTab.text
                    font.pixelSize: 12
                    font.bold: phoneTab.selected
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    color: phoneTab.selected ? MobileTheme.ink : MobileTheme.muted
                }
            }
        }

        background: Rectangle {
            color: phoneTab.down ? MobileTheme.soft : phoneTab.selected ? MobileTheme.sidebar : MobileTheme.paper
            border.width: phoneTab.visualFocus ? 1 : 0
            border.color: MobileTheme.accent

            Rectangle {
                anchors.right: parent.right
                height: parent.height
                width: phoneTab.more ? 0 : 1
                color: MobileTheme.line
            }

            Rectangle {
                visible: phoneTab.selected
                anchors.bottom: parent.bottom
                width: parent.width
                height: 3
                color: MobileTheme.accent
            }

            Rectangle {
                visible: phoneTab.more && sidebar.updateAvailable
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                width: 6
                height: width
                radius: width / 2
                color: MobileTheme.accent
            }
        }

        onClicked: sidebar.pageRequested(pageIndex)
    }

    RowLayout {
        visible: sidebar.phoneLayout
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0

        PhoneTab {
            pageIndex: 0
            text: "Обзор"
            iconPath: "M3 4h8v7H3z M14 4h7v7h-7z M3 14h8v6H3z M14 14h7v6h-7z"
        }

        PhoneTab {
            pageIndex: 1
            text: "Категории"
            iconPath: "M3 7v12h18V7h-9l-2-2H3z M3 10h18"
        }

        Basic.Button {
            id: add

            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(52, Math.min(68, sidebar.width * 0.16))
            padding: 0
            enabled: sidebar.addEnabled
            text: "+"
            Accessible.name: sidebar.currentPage === 0 ? "Добавить операцию"
                : sidebar.currentPage === 1 ? "Добавить категорию"
                : sidebar.currentPage === 2 ? "Добавить счёт"
                : "Добавить"

            contentItem: MobileEditorialText {
                text: add.text
                font.pixelSize: 34
                horizontalAlignment: Text.AlignHCenter
                color: add.enabled ? MobileTheme.sidebar : MobileTheme.muted
            }

            background: Rectangle {
                color: !add.enabled ? MobileTheme.soft : add.down ? MobileTheme.accent : MobileTheme.ink
                border.width: add.visualFocus ? 2 : 1
                border.color: add.visualFocus ? MobileTheme.sidebar : MobileTheme.ink
            }

            onClicked: sidebar.addRequested()
        }

        PhoneTab {
            pageIndex: 2
            text: "Счета"
            iconPath: "M3 6h18v13H3z M3 10h18 M6 15h5"
        }

        PhoneTab {
            pageIndex: 3
            text: "Ещё"
            iconPath: "M5 12h.5 M11.75 12h.5 M18.5 12h.5"
        }
    }

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
        visible: !sidebar.phoneLayout
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 4
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 2

        Repeater {
            model: ["Обзор", "Категории", "Аналитика", "Настройки"]

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
                Accessible.name: section.index === 3 && sidebar.updateAvailable
                    ? section.text + ", доступно обновление" : section.text
                onClicked: sidebar.pageRequested(section.index)

                Rectangle {
                    visible: section.index === 3 && sidebar.updateAvailable
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
            }
        }
    }
}
