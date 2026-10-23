import QtQuick
import QtQuick.Controls
import "../common"
import "../dashboard"

EditorialPage {
    id: page
    title: "Заметки."
    EditorialText {
        width: parent.width
        height: visible ? 48 : 0
        visible: !!page.controller.notesError
        text: page.controller.notesError
        color: "#b84932"
        font.pixelSize: 14
        wrapMode: Text.WordWrap
    }
    Item {
        width: parent.width
        height: Math.max(page.height - page.masthead.height - 72, editor.contentHeight + 40)
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = "#0b031528";
                ctx.lineWidth = 1;
                for (let y = 55.5; y < height; y += 32) {
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                    ctx.stroke();
                }
            }
        }
        TextArea {
            id: editor
            objectName: "editorialNotesEditor"
            property bool loaded: false
            width: parent.width
            height: parent.height
            topPadding: 24
            bottomPadding: 8
            leftPadding: 0
            rightPadding: 0
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            readOnly: !page.controller.notesAvailable
            color: "#031528"
            placeholderTextColor: "#59616a"
            selectionColor: "#031528"
            selectedTextColor: "#f3eddf"
            font.family: "Arimo"
            font.pixelSize: 18
            placeholderText: "Запишите мысли, планы или важные детали…"
            background: null
            Component.onCompleted: {
                text = page.controller.notesText;
                notebookLayout.attach(textDocument);
                loaded = true;
            }
            onTextChanged: if (loaded) {
                               notebookLayout.attach(textDocument);
                               page.controller.setNotesText(text);
                           }
            onActiveFocusChanged: if (!activeFocus && loaded)
                                      page.controller.saveNotes()
            Connections {
                target: page.controller
                function onNotesChanged() {
                    if (!editor.loaded || editor.text === page.controller.notesText)
                        return;
                    const position = editor.cursorPosition;
                    editor.loaded = false;
                    editor.text = page.controller.notesText;
                    notebookLayout.attach(editor.textDocument);
                    editor.cursorPosition = Math.min(position, editor.length);
                    editor.loaded = true;
                }
            }
        }
    }
    Shortcut {
        sequences: [StandardKey.Save]
        enabled: page.visible
        onActivated: page.controller.saveNotes()
    }
    Component.onDestruction: controller.saveNotes()
}
