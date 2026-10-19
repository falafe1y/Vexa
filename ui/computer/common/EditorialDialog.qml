import QtQuick
import QtQuick.Controls
import "EditorialStyle.js" as Appearance

Dialog {
    id: dialog
    readonly property bool editorial: Appearance.desktop
    padding: 24
    font.family: editorial ? "Arimo" : "Commissioner"
    font.pixelSize: editorial ? 16 : 14
    // Zero on desktop. On mobile the dialog is centred between the status bar/cutout and the gesture bar.
    readonly property real insetTop: parent ? parent.SafeArea.margins.top : 0
    readonly property real insetBottom: parent ? parent.SafeArea.margins.bottom : 0
    height: Math.min(implicitHeight, parent ? Math.max(0, parent.height - insetTop - insetBottom - 48) : implicitHeight)
    palette.window: "#f3eddf"
    palette.base: "#f3eddf"
    palette.button: "#f3eddf"
    palette.text: "#031528"
    palette.windowText: "#031528"
    palette.buttonText: "#031528"
    palette.highlight: "#031528"
    palette.highlightedText: "#f3eddf"
    palette.toolTipBase: "#031528"
    palette.toolTipText: "#f3eddf"

    header: EditorialDialogTitle {
        text: dialog.title
        visible: text.length > 0
        leftPadding: dialog.leftPadding
        rightPadding: dialog.rightPadding
        topPadding: 24
    }
    background: Rectangle {
        color: "#f3eddf"
        border.color: "#031528"
    }
    footer: DialogButtonBox {
        visible: count > 0
        spacing: 12
        padding: 24
        delegate: StyledButton {}
        background: Item {
            Rectangle {
                width: parent.width
                height: 1
                color: "#031528"
            }
        }
    }
}
