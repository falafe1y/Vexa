pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: heading

    required property string title
    required property bool landscape
    property string number: ""
    property alias actions: controls.data

    spacing: 8
    Layout.preferredHeight: Math.max(MobileTheme.touchSize, controls.implicitHeight)

    MobileEditorialText {
        visible: heading.landscape && heading.number.length > 0
        text: heading.number
        font.family: MobileTheme.mono
        font.pixelSize: 12
        color: MobileTheme.accent
    }

    MobileEditorialText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: heading.landscape ? heading.title.toUpperCase() : heading.title
        font.family: heading.landscape ? MobileTheme.sans : MobileTheme.serif
        font.pixelSize: heading.landscape ? 15 : 27
        font.bold: heading.landscape
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 12
        Accessible.role: Accessible.Heading
    }

    RowLayout {
        id: controls

        spacing: 10
    }
}
