import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property bool loaded: false
    Component.onCompleted: {
        editor.text = financeController.notesText;
        notebookLayout.attach(editor.textDocument);
        page.loaded = true;
    }
    Component.onDestruction: financeController.saveNotes()
    Connections {
        target: financeController
        function onNotesChanged() {
            if (!page.loaded || editor.text === financeController.notesText)
                return;
            page.loaded = false;
            editor.text = financeController.notesText;
            page.loaded = true;
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        MobileText {
            font.family: MobileTheme.mono
            Layout.fillWidth: true
            visible: financeController.notesError.length > 0
            text: financeController.notesError
            wrapMode: Text.Wrap
            color: MobileTheme.red
            font.pixelSize: 12
        }
        ScrollView {
            id: notesScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            TextArea {
                id: editor
                objectName: "mobileNotesEditor"
                width: notesScroll.availableWidth
                readOnly: !financeController.notesAvailable
                wrapMode: TextArea.Wrap
                selectByMouse: true
                leftPadding: 0
                rightPadding: 0
                topPadding: 8
                bottomPadding: 24
                font.family: MobileTheme.sans
                font.pixelSize: 16
                color: MobileTheme.accent
                placeholderText: qsTr("Запишите мысли, планы и напоминания")
                placeholderTextColor: MobileTheme.muted
                background: Item {
                    Repeater {
                        model: Math.ceil(parent.height / 32)
                        Rectangle {
                            required property int index
                            y: 8 + (index + 1) * 32
                            width: editor.width
                            height: 1
                            color: MobileTheme.line
                            opacity: 0.3
                        }
                    }
                }
                onTextChanged: {
                    if (page.loaded)
                        financeController.setNotesText(text);
                }
                onActiveFocusChanged: {
                    if (!activeFocus && page.loaded)
                        financeController.saveNotes();
                }
            }
        }
    }
}
