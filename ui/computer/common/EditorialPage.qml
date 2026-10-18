import QtQuick
import QtQuick.Controls

Flickable {
    id: page
    required property var host
    required property var controller
    property string title: ""
    property bool period: false
    readonly property bool small: host.width <= 1150
    readonly property int pad: host.width <= 850 ? 20 : host.width <= 1150 ? 24 : host.width <= 1500 ? 32 : 48
    default property alias pageContents: body.data
    property alias body: body
    property alias masthead: masthead
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: Math.max(height, paper.height + 48)
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AlwaysOff
    }
    Rectangle {
        parent: page
        anchors.fill: parent
        z: -1
        color: "#f3eddf"
    }
    Item {
        id: paper
        objectName: "editorialPagePaper"
        x: page.pad
        y: 24
        width: Math.max(0, page.width - page.pad * 2)
        height: masthead.height + body.height
        EditorialMasthead {
            id: masthead
            width: parent.width
            height: implicitHeight
            host: page.host
            controller: page.controller
            title: page.title
            period: page.period
        }
        Column {
            id: body
            y: masthead.height
            width: parent.width
            spacing: 0
        }
    }
}
