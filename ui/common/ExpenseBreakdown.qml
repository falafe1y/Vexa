pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

ColumnLayout {
    id: section

    required property var ledger
    required property QtObject theme

    spacing: 14

    component BreakdownText: Text {
        color: section.theme.ink
        font.family: section.theme.sans
        font.pixelSize: 14
        textFormat: Text.PlainText
    }

    BreakdownText {
        Layout.fillWidth: true
        text: "Расходы по категориям"
        font.family: section.theme.serif
        font.pixelSize: 23
        wrapMode: Text.Wrap
        Accessible.role: Accessible.Heading
    }

    BreakdownText {
        Layout.fillWidth: true
        text: "За всё время"
        color: section.theme.muted
    }

    BreakdownText {
        Layout.fillWidth: true
        visible: sectors.count > 0
        text: "Всего " + section.ledger.expenseTotalText
        font.family: section.theme.mono
        font.pixelSize: 18
        font.bold: true
        wrapMode: Text.Wrap
    }

    BreakdownText {
        Layout.fillWidth: true
        visible: sectors.count === 0
        text: section.ledger.expenseSummaryCaption
        color: section.theme.muted
        wrapMode: Text.Wrap
    }

    GridLayout {
        Layout.fillWidth: true
        visible: sectors.count > 0
        columns: section.width >= 640 ? 2 : 1
        columnSpacing: 28
        rowSpacing: 22

        Item {
            id: chart

            readonly property real diameter: Math.max(0, Math.min(section.width, 300))

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredWidth: diameter
            Layout.preferredHeight: diameter

            Repeater {
                id: sectors

                model: section.visible ? section.ledger.expenseSummaryModel : null

                delegate: Shape {
                    id: sector

                    required property int index
                    required property bool isOther
                    readonly property color sectorColor: sector.isOther
                        ? section.theme.expenseOtherColor
                        : section.theme.expenseCategoryColors[sector.index]
                    required property real startAngle
                    required property real sweepAngle

                    anchors.fill: chart
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        fillColor: sector.sectorColor
                        startX: chart.width / 2
                        startY: chart.height / 2

                        PathAngleArc {
                            centerX: chart.width / 2
                            centerY: chart.height / 2
                            radiusX: chart.width / 2
                            radiusY: chart.height / 2
                            startAngle: sector.startAngle
                            sweepAngle: sector.sweepAngle
                            moveToStart: false
                        }

                        PathLine {
                            x: chart.width / 2
                            y: chart.height / 2
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignTop
            spacing: 0

            Repeater {
                model: section.visible ? section.ledger.expenseSummaryModel : null

                delegate: ColumnLayout {
                    id: entry

                    required property string name
                    required property string amountText
                    required property string shareText
                    required property int index
                    required property bool isOther
                    readonly property color sectorColor: entry.isOther
                        ? section.theme.expenseOtherColor
                        : section.theme.expenseCategoryColors[entry.index]

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 9
                        Layout.bottomMargin: 9
                        spacing: 8

                        Rectangle {
                            implicitWidth: 10
                            implicitHeight: 10
                            color: entry.sectorColor
                        }

                        BreakdownText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: entry.name
                            wrapMode: Text.Wrap
                        }

                        BreakdownText {
                            Layout.maximumWidth: Math.max(0, entry.width * 0.43)
                            text: entry.amountText
                            font.family: section.theme.mono
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.Wrap
                        }

                        BreakdownText {
                            Layout.preferredWidth: 64
                            text: entry.shareText
                            color: section.theme.muted
                            font.family: section.theme.mono
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: section.theme.line
                    }
                }
            }
        }
    }
}
