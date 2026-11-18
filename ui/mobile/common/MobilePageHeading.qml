import QtQuick

MobileEditorialText {
    id: heading

    property bool documentStyle: false

    font.family: MobileTheme.serif
    font.pixelSize: documentStyle ? 27 : 38
    font.italic: !documentStyle
    font.bold: documentStyle
    font.letterSpacing: documentStyle ? 0 : -1
    fontSizeMode: Text.HorizontalFit
    minimumPixelSize: 22
    topPadding: documentStyle ? 8 : 0
    bottomPadding: documentStyle ? 10 : 0
    Accessible.role: Accessible.Heading

    Rectangle {
        visible: heading.documentStyle
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: MobileTheme.ink
    }
}
