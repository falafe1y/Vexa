import QtQuick
import UI

InputField {
    id: control

    // Разрешены цифры и не более одной запятой.
    // Незавершённое значение "150," допустимо во время ввода.
    validator: RegularExpressionValidator {
        regularExpression: /^\d+(,\d{0,2})?$/
    }
    inputMethodHints: Qt.ImhFormattedNumbersOnly

    // Для вычислений в ядре отбрасываем завершающую запятую.
    readonly property string normalizedText: text.endsWith(",")
        ? text.slice(0, -1) : text
}
