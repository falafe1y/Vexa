import QtQuick
import QtQuick.Controls
import UI

Item {
    id: row
    property bool heading: false
    property string recordId: ""
    property string dateText: ""
    property string dateIso: ""
    property string accountId: ""
    property string secondaryId: ""
    property string amountInput: ""
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
    signal editRequested(var data)

    implicitHeight: heading ? 40 : 56
    height: implicitHeight
    Rectangle { anchors.fill: parent; color: row.heading ? DesktopTheme.soft : "transparent" }
    Rectangle { width: parent.width; height: 1; color: row.heading ? DesktopTheme.ink : DesktopTheme.line; anchors.bottom: parent.bottom }
    Rectangle { visible: row.heading; width: parent.width; height: 1; color: DesktopTheme.ink }

    // Column widths match the original editorial dashboard grid.
    readonly property var fractions: width <= 800 ? [.15, .13, .24, .20, 0, .28]
                                                 : [.10101, .09596, .14647, .12626, .37879, .15151]
    component Cell: EditorialText {
        property real fraction: 0
        property bool numeric: false
        width: row.width * fraction
        height: row.height
        rightPadding: 8
        font.family: row.heading ? DesktopTheme.mono : DesktopTheme.sans
        font.pixelSize: row.heading ? 12 : row.width <= 800 ? 12 : 14
        horizontalAlignment: numeric ? Text.AlignRight : Text.AlignLeft
    }
    Row {
        anchors.fill: parent
        spacing: 0
        Cell { fraction: row.fractions[0]; text: row.dateText; font.family: DesktopTheme.mono }
        Cell { fraction: row.fractions[1]; text: row.typeText; font.family: DesktopTheme.mono; color: row.heading ? DesktopTheme.ink : DesktopTheme.muted }
        Cell { fraction: row.fractions[2]; text: row.accountText }
        Cell { fraction: row.fractions[3]; text: row.categoryText }
        Cell { fraction: row.fractions[4]; text: row.heading ? "ОПИСАНИЕ" : row.descriptionText; visible: fraction > 0 }
        Cell {
            fraction: row.fractions[5]; numeric: true
            text: row.primaryAmountText
            font.bold: !row.heading
            color: row.heading ? DesktopTheme.ink : row.operationType === 0 ? DesktopTheme.income : DesktopTheme.accent
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !row.heading && !row.busy
        onTapped: (point, button) =>
            operationContextMenu.openAt(point.position.x, point.position.y)
    }
    ContextActionMenu {
        id: operationContextMenu
        editEnabled: !row.busy && !row.heading
        onEditRequested: row.editRequested({
            id: row.recordId,
            type: row.operationType,
            accountId: row.accountId,
            secondaryId: row.secondaryId,
            amountInput: row.amountInput,
            dateIso: row.dateIso
        })
        removeEnabled: !row.busy && !row.heading
        onRemoveRequested: row.removeRequested(row.recordId, row.descriptionText)
    }
}
