import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Keep the original form items and their layout properties inside a bounded viewport.
EditorialScrollView {
    id: view
    default property alias formData: form.data
    spacing: 16
    implicitHeight: form.implicitHeight
    contentWidth: availableWidth
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ColumnLayout {
        id: form
        width: view.availableWidth
        spacing: view.spacing
    }
}
