import QtQuick
import QtQuick.Layouts

Column {
    id: section
    property int number: 1
    property string title: ""
    property Component toolbar: null
    default property alias contents: body.data
    spacing: 24
    Item {
        width: 1
        height: 0
    }
    GridLayout {
        width: parent.width
        columns: section.width < 900 ? 1 : 2
        columnSpacing: 24
        rowSpacing: 8
        EditorialSection {
            Layout.fillWidth: true
            number: section.number
            title: section.title
        }
        Loader {
            sourceComponent: section.toolbar
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
        }
    }
    Column {
        id: body
        width: parent.width
        spacing: 24
    }
    Rectangle {
        width: parent.width
        height: 1
        color: "#031528"
    }
}
