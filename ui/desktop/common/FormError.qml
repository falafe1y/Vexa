import QtQuick
import UI

EditorialText {
    property string message: ""
    visible: message.length > 0
    text: message
    color: DesktopTheme.accent
    wrapMode: Text.WordWrap
}
