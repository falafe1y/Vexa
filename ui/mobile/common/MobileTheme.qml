pragma Singleton
import QtQuick

QtObject {
    readonly property color paper: "#f3eddf"
    readonly property color sidebar: "#f9f6ea"
    readonly property color soft: "#e9e0ce"
    readonly property color ink: "#031528"
    readonly property color muted: "#59616a"
    readonly property color line: "#bbb5a8"
    readonly property color accent: "#b84932"
    readonly property color income: "#2e5947"
    readonly property list<color> expenseCategoryColors: [
        "#D67B50",
        "#E3895A",
        "#EB9766",
        "#F0A675",
        "#F5B487",
        "#F8C29B",
        "#FBD0AE"
    ]
    readonly property color expenseOtherColor: muted
    readonly property string sans: "Arimo"
    readonly property string serif: "PT Serif"
    readonly property int menuItemHeight: touchSize
    readonly property int menuPadding: 1
    readonly property int menuTextPadding: 14
    readonly property string mono: "Cousine"

    readonly property int pagePadding: 16
    readonly property int touchSize: 48
}
