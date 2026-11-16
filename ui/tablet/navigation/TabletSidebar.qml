pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts

Rectangle {
    id: sidebar

    required property var updates
    property int currentPage: 0
    signal pageRequested(int page)

    color: MobileTheme.sidebar

    component NavigationButton: Basic.Button {
        id: button

        required property int pageIndex
        property string marker: ""
        readonly property bool selected: sidebar.currentPage === pageIndex

        implicitHeight: MobileTheme.touchSize
        padding: 0
        hoverEnabled: true
        Accessible.selected: selected
        onClicked: sidebar.pageRequested(pageIndex)

        contentItem: RowLayout {
            spacing: 10

            MobileEditorialText {
                Layout.preferredWidth: 22
                text: button.marker
                font.family: MobileTheme.mono
                font.pixelSize: 12
                color: button.selected ? MobileTheme.accent : MobileTheme.muted
            }

            MobileEditorialText {
                Layout.fillWidth: true
                text: button.text
                font.bold: button.selected
                color: button.hovered ? MobileTheme.accent : MobileTheme.ink
            }
        }

        background: Item {
            Rectangle {
                anchors.fill: parent
                color: MobileTheme.soft
                visible: button.down || button.visualFocus
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                visible: button.selected
                color: MobileTheme.line
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: MobileTheme.ink
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: sidebar.width < 165 ? 10 : 17
        spacing: 8

        MobileEditorialText {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 10
            text: "Vexa."
            font.family: "Gelasio"
            font.italic: true
            font.bold: true
            font.pixelSize: sidebar.width < 165 ? 36 : 46
            font.letterSpacing: -2
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: MobileTheme.ink
        }

        Flickable {
            id: sections

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: links.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            Basic.ScrollIndicator.vertical: Basic.ScrollIndicator {}

            ColumnLayout {
                id: links

                width: sections.width
                spacing: 0

                NavigationButton {
                    Layout.fillWidth: true
                    pageIndex: 0
                    marker: "01"
                    text: "Обзор"
                }

                NavigationButton {
                    Layout.fillWidth: true
                    pageIndex: 1
                    marker: "02"
                    text: "Категории"
                }

                Repeater {
                    model: ["Цели", "Заметки", "Траектория", "Бюджеты", "Проекты"]

                    delegate: RowLayout {
                        id: section

                        required property int index
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: MobileTheme.touchSize
                        spacing: 10

                        MobileEditorialText {
                            Layout.preferredWidth: 22
                            text: "0" + (section.index + 3)
                            font.family: MobileTheme.mono
                            font.pixelSize: 12
                            color: MobileTheme.muted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            MobileEditorialText {
                                Layout.fillWidth: true
                                text: section.modelData
                                color: MobileTheme.muted
                            }

                            MobileEditorialText {
                                Layout.fillWidth: true
                                text: "В разработке"
                                color: MobileTheme.muted
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                NavigationButton {
                    Layout.fillWidth: true
                    pageIndex: 2
                    marker: "08"
                    text: "Аналитика"
                }
            }
        }

        MobileActionButton {
            Layout.fillWidth: true
            visible: sidebar.updates.updateAvailable && sidebar.height >= 660
            text: "ОБНОВИТЬ"
            onClicked: sidebar.updates.openReleasePage()
        }

        NavigationButton {
            Layout.fillWidth: true
            pageIndex: 3
            marker: "⚙"
            text: "Настройки"
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: MobileTheme.ink
        }

        RowLayout {
            Layout.fillWidth: true

            MobileEditorialText {
                Layout.fillWidth: true
                text: "VEXA"
                font.family: MobileTheme.mono
                font.pixelSize: 12
                color: MobileTheme.muted
            }

            MobileEditorialText {
                text: "v" + sidebar.updates.currentVersion
                font.family: MobileTheme.mono
                font.pixelSize: 12
                color: MobileTheme.muted
            }
        }
    }
}
