import QtQuick

MobileInputField {
    validator: RegularExpressionValidator {
        regularExpression: /^\d+([.,]\d{0,2})?$/
    }
    inputMethodHints: Qt.ImhFormattedNumbersOnly

    readonly property string normalizedText: text.replace(/[.,]$/, "").replace(".", ",")
}
