pragma Singleton
import QtQuick

QtObject {
    readonly property color canvas: "#f3eddf"
    readonly property color panel: canvas
    readonly property color soft: canvas
    readonly property color line: "#bbb5a8"
    readonly property color accent: "#031528"
    readonly property color accentText: canvas
    readonly property color muted: "#59616a"
    readonly property color accentSoft: accent
    readonly property color pale: "#e9e4d8"
    readonly property color navSelected: accent
    readonly property color copper: "#be7b56"
    readonly property color red: "#a24e38"
    readonly property color income: "#2e5947"
    readonly property color incomePanel: pale
    readonly property color expensePanel: pale
    readonly property color tableHeader: "#e9e0ce"
    readonly property color hover: pale
    readonly property var chartColors: [accent, copper, "#a99d87", "#6e796c", "#c9bfac"]
    readonly property color designCanvas: canvas
    readonly property color designBand: tableHeader
    readonly property color designCard: panel
    readonly property color designInk: accent
    readonly property color designNavy: accent
    readonly property color designMuted: muted
    readonly property color designLight: line
    readonly property color designCream: canvas
    readonly property color designIncome: income
    readonly property color designExpense: red
    readonly property color designShadow: "transparent"
    readonly property string sans: "Arimo"
    readonly property string serif: "PT Serif"
    readonly property string mono: "Cousine"
    property bool hideAmounts: false
    readonly property int margin: 20
    readonly property int touchHeight: 48
    readonly property int radiusControl: 0
    readonly property int radiusCard: 0
    readonly property int radiusSheet: 0
    readonly property int shadowDepth: 0
    readonly property int navInset: 32
    readonly property int sizeDisplay: 40
    readonly property int sizeTitle: 28
    readonly property int sizeHeading: 24
    readonly property int sizeBody: 16
    readonly property int sizeCaption: 12
    readonly property int sizeLabel: 12
}
