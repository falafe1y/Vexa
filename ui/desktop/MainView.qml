import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

ApplicationWindow {
    id: window
    required property var ledger
    required property var updates

    width: 1600
    height: 960
    minimumWidth: 1050
    minimumHeight: 650
    visible: true
    title: "Vexa"
    color: DesktopTheme.paper
    font.family: DesktopTheme.sans
    font.pixelSize: 16
    palette.window: DesktopTheme.paper
    palette.base: DesktopTheme.sidebar
    palette.text: DesktopTheme.ink
    palette.windowText: DesktopTheme.ink
    palette.buttonText: DesktopTheme.ink
    palette.button: DesktopTheme.paper
    palette.highlight: DesktopTheme.ink
    palette.highlightedText: DesktopTheme.paper

    AccountDialog { id: accountDialog; ledger: window.ledger }
    CategoryDialog { id: categoryDialog; ledger: window.ledger }
    OperationDialog { id: operationDialog; ledger: window.ledger }
    RemovalDialog { id: removalDialog; ledger: window.ledger }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            updates: window.updates
            Layout.preferredWidth: window.width <= 850 ? 72 : window.width <= 1150 ? 184 : window.width <= 1500 ? 208 : 240
            Layout.fillHeight: true
            currentPage: pages.currentIndex
            onPageRequested: page => pages.currentIndex = page
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StackLayout {
                id: pages
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: 0

                DashboardPage {
                    ledger: window.ledger
                    onCreateAccountRequested: accountDialog.open()
                    onEditAccountRequested: data => accountDialog.openForEdit(data)
                    onOperationRequested: type => operationDialog.openFor(type)
                    onEditOperationRequested: data => operationDialog.openForEdit(data)
                    onRemoveAccountRequested: (recordId, description) =>
                        removalDialog.ask("removeAccount", recordId, description)
                    onRemoveOperationRequested: (recordId, description) =>
                        removalDialog.ask("removeOperation", recordId, description)
                }

                CategoriesPage {
                    ledger: window.ledger
                    onCreateRequested: categoryDialog.open()
                    onEditRequested: data => categoryDialog.openForEdit(data)
                    onRemoveRequested: (recordId, description) =>
                        removalDialog.ask("removeCategory", recordId, description)
                }

                SettingsPage {
                    ledger: window.ledger
                    updates: window.updates
                }
            }
        }
    }
}
