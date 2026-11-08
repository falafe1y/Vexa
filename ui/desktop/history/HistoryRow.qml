import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UI

Rectangle {
    id: row
    property bool heading: false
    property string recordId: ""
    property string dateText: ""
    property string typeText: ""
    property int operationType: 0
    property string accountText: ""
    property string secondaryAccountText: ""
    property string categoryText: ""
    property string primaryAmountText: ""
    property string secondaryAmountText: ""
    property string descriptionText: ""
    property bool busy: false
    signal removeRequested(string recordId, string description)

    implicitHeight: heading ? 40 : 76
    color: heading ? DesktopTheme.soft : "transparent"

    Rectangle {
        anchors.bottom: parent.bottom
        height: 1
        width: parent.width
        color: row.heading ? DesktopTheme.ink : DesktopTheme.line
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        EditorialText {
            Layout.preferredWidth: 78
            text: row.dateText
            font.family: DesktopTheme.mono
            font.pixelSize: row.heading ? 10 : 11
        }
        EditorialText {
            Layout.preferredWidth: 60
            text: row.typeText
            font.pixelSize: row.heading ? 10 : 12
            font.family: row.heading ? DesktopTheme.mono : DesktopTheme.sans
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 180
            Layout.minimumWidth: 100
            spacing: 4
            EditorialText {
                Layout.fillWidth: true
                text: row.accountText
                font.pixelSize: row.heading ? 10 : 12
                font.family: row.heading ? DesktopTheme.mono : DesktopTheme.sans
            }
            EditorialText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: row.secondaryAccountText
                color: DesktopTheme.muted
                font.pixelSize: 11
            }
        }
        EditorialText {
            Layout.fillWidth: true
            Layout.preferredWidth: 130
            Layout.minimumWidth: 72
            text: row.categoryText
            font.pixelSize: row.heading ? 10 : 12
            font.family: row.heading ? DesktopTheme.mono : DesktopTheme.sans
        }
        ColumnLayout {
            Layout.preferredWidth: 144
            spacing: 4
            EditorialText {
                Layout.fillWidth: true
                text: row.primaryAmountText
                horizontalAlignment: Text.AlignRight
                font.family: row.heading ? DesktopTheme.mono : DesktopTheme.sans
                font.pixelSize: row.heading ? 10 : 13
                fontSizeMode: Text.Fit
                minimumPixelSize: 10
                color: row.heading ? DesktopTheme.ink
                       : row.operationType === 0 ? DesktopTheme.income : DesktopTheme.accent
            }
            EditorialText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: row.secondaryAmountText
                horizontalAlignment: Text.AlignRight
                font.pixelSize: 12
                fontSizeMode: Text.Fit
                minimumPixelSize: 10
                color: DesktopTheme.income
            }
        }
        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            ActionButton {
                anchors.fill: parent
                visible: !row.heading
                enabled: !row.busy
                text: "×"
                outlined: false
                leftPadding: 0
                rightPadding: 0
                danger: true
                Accessible.name: "Удалить операцию"
                ToolTip.visible: hovered
                ToolTip.text: "Удалить операцию"
                onClicked: row.removeRequested(row.recordId, row.descriptionText)
            }
        }
    }
}
