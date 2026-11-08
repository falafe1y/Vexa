import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

ApplicationWindow {
    id: window
    required property var ledger
    property string errorText: ""

    width: 1280
    height: 900
    minimumWidth: 900
    minimumHeight: 700
    maximumWidth: 1920
    maximumHeight: 1080
    visible: true
    title: "Vexa"
    color: DesktopTheme.paper
    font.family: DesktopTheme.sans
    font.pixelSize: 14
    palette.window: DesktopTheme.paper
    palette.base: DesktopTheme.sidebar
    palette.text: DesktopTheme.ink
    palette.windowText: DesktopTheme.ink
    palette.buttonText: DesktopTheme.ink
    palette.button: DesktopTheme.paper
    palette.highlight: DesktopTheme.ink
    palette.highlightedText: DesktopTheme.paper

    Connections {
        target: window.ledger
        function onErrorOccurred(message) { window.errorText = message }
    }

    AccountDialog { id: accountDialog; ledger: window.ledger }
    CategoryDialog { id: categoryDialog; ledger: window.ledger }
    OperationDialog { id: operationDialog; ledger: window.ledger }
    RemovalDialog { id: removalDialog; ledger: window.ledger }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            Layout.preferredWidth: window.width < 1200 ? 176 : 216
            Layout.fillHeight: true
            currentPage: pages.currentIndex
            onPageRequested: page => pages.currentIndex = page
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: DesktopTheme.paper
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    EditorialText {
                        Layout.fillWidth: true
                        text: window.ledger.ready ? "ЛОКАЛЬНЫЙ УЧЁТ" : "ОТКРЫВАЕМ БАЗУ…"
                        color: DesktopTheme.muted
                        font.family: DesktopTheme.mono
                        font.pixelSize: 10
                    }
                    ActionButton {
                        text: "ОБНОВИТЬ"
                        implicitHeight: 30
                        outlined: false
                        enabled: window.ledger.ready && !window.ledger.commandPending
                        onClicked: {
                            window.errorText = ""
                            window.ledger.refresh()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: errorContent.implicitHeight + 20
                visible: window.errorText.length > 0
                color: DesktopTheme.soft
                RowLayout {
                    id: errorContent
                    anchors.fill: parent
                    anchors.margins: 10
                    EditorialText {
                        Layout.fillWidth: true
                        text: window.errorText
                        color: DesktopTheme.accent
                        wrapMode: Text.WordWrap
                    }
                    ActionButton {
                        text: "×"
                        implicitWidth: 32
                        outlined: false
                        onClicked: window.errorText = ""
                    }
                }
            }

            StackLayout {
                id: pages
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: 0

                DashboardPage {
                    ledger: window.ledger
                    onCreateAccountRequested: accountDialog.open()
                    onOperationRequested: type => operationDialog.openFor(type)
                    onRemoveAccountRequested: (recordId, description) =>
                        removalDialog.ask("removeAccount", recordId, description)
                    onRemoveOperationRequested: (recordId, description) =>
                        removalDialog.ask("removeOperation", recordId, description)
                }
                CategoriesPage {
                    ledger: window.ledger
                    onCreateRequested: categoryDialog.open()
                    onRemoveRequested: (recordId, description) =>
                        removalDialog.ask("removeCategory", recordId, description)
                }
                SettingsPage { ledger: window.ledger }
            }
        }
    }
}
