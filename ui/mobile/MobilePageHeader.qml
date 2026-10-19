import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: header
    required property var host
    spacing: 0
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 16
        visible: header.host.moneyControls
        spacing: 8
        MobileChip {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: header.host.periodControls
            text: header.host.dateFilterLabel()
            onClicked: header.host.openPeriod()
        }
        Item {
            Layout.fillWidth: true
            visible: !header.host.periodControls
        }
        MobileChip {
            text: financeController.appCurrency
            onClicked: header.host.openCurrency()
        }
        MobileIconButton {
            icon: header.host.hideAmounts ? "eyeOff" : "eye"
            Accessible.name: header.host.hideAmounts ? qsTr("Показать суммы") : qsTr("Скрыть суммы")
            onClicked: header.host.hideAmounts = !header.host.hideAmounts
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        MobileIconButton {
            visible: header.host.pageHistory.length > 0
            icon: "chevronLeft"
            onClicked: header.host.goBack()
        }
        MobileText {
            objectName: "mobilePageTitle"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: header.host.pageTitle().replace(/\.$/, "") + "."
            font.family: MobileTheme.serif
            font.italic: true
            font.pixelSize: header.host.width < 360 ? 36 : 40
            wrapMode: Text.Wrap
            bottomPadding: 16
        }
    }
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: MobileTheme.accent
    }
}
