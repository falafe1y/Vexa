pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window

    required property var ledger
    required property var updates

    width: 1280
    height: 800
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
        maximumWidth: 552
        centered: true
    }

    MobileCategoryDialog {
        id: categoryDialog

        parent: window.contentItem
        ledger: window.ledger
        maximumWidth: 552
        centered: true
    }

    MobileOperationDialog {
        id: operationDialog

        parent: window.contentItem
        ledger: window.ledger
        maximumWidth: 552
        centered: true
    }

    MobileRemovalDialog {
        id: removalDialog

        parent: window.contentItem
        ledger: window.ledger
        maximumWidth: 552
        centered: true
    }

    Item {
        id: shell

        anchors.fill: parent

        readonly property bool landscape: width >= 800 && width > window.height

        TabletSidebar {
            id: sidebar

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: Math.max(141, Math.min(218, Math.round(shell.width * 0.15)))
            visible: shell.landscape
            updates: window.updates
            currentPage: pages.currentIndex
            onPageRequested: page => pages.currentIndex = page
        }

        StackLayout {
            id: pages

            anchors.fill: parent
            anchors.leftMargin: shell.landscape ? sidebar.width : 0
            anchors.bottomMargin: shell.landscape ? 0 : bottomNavigation.height
            currentIndex: 0

            TabletDashboardPage {
                landscape: shell.landscape
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

            TabletCategoriesPage {
                landscape: shell.landscape
                ledger: window.ledger
                onCreateRequested: type => categoryDialog.openFor(type)
                onEditRequested: data => categoryDialog.openForEdit(data)
                onRemoveRequested: (recordId, description) =>
                    removalDialog.ask("removeCategory", recordId, description)
            }

            TabletSettingsPage {
                landscape: shell.landscape
                ledger: window.ledger
                updates: window.updates
            }
        }

        MobileSidebar {
            id: bottomNavigation

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: implicitHeight
            visible: !shell.landscape
            currentPage: pages.currentIndex
            updateAvailable: window.updates.updateAvailable
            onPageRequested: page => pages.currentIndex = page
        }
    }
}
