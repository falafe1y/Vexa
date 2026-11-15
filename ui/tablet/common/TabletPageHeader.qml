pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: header

    required property bool landscape
    required property string title
    property alias actions: controls.data

    spacing: 14

    MobileEditorialText {
        Layout.fillWidth: true
        visible: !header.landscape
        text: "Vexa."
        font.family: "Gelasio"
        font.italic: true
        font.bold: true
        font.pixelSize: 38
        font.letterSpacing: -1.5
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        visible: !header.landscape
        color: MobileTheme.ink
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MobilePageHeading {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignBottom
            text: header.title
            font.pixelSize: header.landscape
                ? (header.width <= 920 ? 56 : 72)
                : Math.round(Math.max(38, Math.min(58, header.width * 0.062)))
            font.letterSpacing: -2
        }

        RowLayout {
            id: controls

            Layout.alignment: Qt.AlignBottom
            spacing: 16
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: MobileTheme.ink
    }
}
