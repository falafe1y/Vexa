pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window

    required property var ledger
    required property var updates

    width: 390
    height: 844
    visibility: Qt.platform.os === "android" || Qt.platform.os === "ios"
        ? Window.Maximized : Window.Windowed
    title: "Vexa"
    color: MobileTheme.paper
    font.family: MobileTheme.sans
    font.pixelSize: 16
    palette.window: MobileTheme.paper
    palette.base: MobileTheme.sidebar
    palette.text: MobileTheme.ink
    palette.windowText: MobileTheme.ink
    palette.buttonText: MobileTheme.ink
    palette.button: MobileTheme.paper
    palette.highlight: MobileTheme.ink
    palette.highlightedText: MobileTheme.sidebar

    MobileAccountDialog {
        id: accountDialog
        parent: window.contentItem
        ledger: window.ledger
    }

    MobileCategoryDialog {
        id: categoryDialog
        parent: window.contentItem
        ledger: window.ledger
    }

    MobileOperationDialog {
        id: operationDialog
        parent: window.contentItem
        ledger: window.ledger
    }

    MobileRemovalDialog {
        id: removalDialog
        parent: window.contentItem
        ledger: window.ledger
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Rectangle {
        //     Layout.fillWidth: true
        //     Layout.preferredHeight: 48
        //     color: MobileTheme.sidebar

        //     MobileEditorialText {
        //         anchors.left: parent.left
        //         anchors.leftMargin: MobileTheme.pagePadding
        //         anchors.verticalCenter: parent.verticalCenter
        //         text: "FPFAPWFAWFAWFWAFWAF."
        //         font.family: "Gelasio"
        //         font.italic: true
        //         font.bold: true
        //         font.pixelSize: 28
        //         font.letterSpacing: -1
        //     }

        //     Rectangle {
        //         anchors.bottom: parent.bottom
        //         width: parent.width
        //         height: 1
        //         color: MobileTheme.ink
        //     }
        // }

        StackLayout {
            id: pages

            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            MobileDashboardPage {
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

            MobileCategoriesPage {
                ledger: window.ledger
                onCreateRequested: type => categoryDialog.openFor(type)
                onEditRequested: data => categoryDialog.openForEdit(data)
                onRemoveRequested: (recordId, description) =>
                    removalDialog.ask("removeCategory", recordId, description)
            }

            MobileAnalyticsPage {
                ledger: window.ledger
            }

            MobileSettingsPage {
                ledger: window.ledger
                updates: window.updates
            }
        }

        MobileSidebar {
            Layout.fillWidth: true
            currentPage: pages.currentIndex
            updateAvailable: window.updates.updateAvailable
            onPageRequested: page => pages.currentIndex = page
        }
    }
}
