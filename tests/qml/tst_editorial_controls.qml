import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest
import "../../ui/computer/common"

Control {
    id: scene
    width: 1280
    height: 800
    palette.text: "white"
    palette.windowText: "white"
    palette.buttonText: "white"
    palette.window: "#202020"
    background: Rectangle {
        color: "#f3eddf"
    }
    property int submitted: 0

    StyledComboBox {
        id: choice
        x: 24
        y: 24
        width: 360
        model: [
            {
                label: "Без капитализации",
                value: "none"
            },
            {
                label: "Ежемесячно",
                value: "monthly"
            },
            {
                label: "Ежегодно",
                value: "yearly"
            }
        ]
        textRole: "label"
        valueRole: "value"
    }
    StyledCheckBox {
        id: wrappingCheck
        x: 24
        y: 96
        width: 160
        text: "Учитывать выбранные счета и категории расходов"
    }
    EditorialMenu {
        id: menu
        x: 400
        y: 24
        EditorialMenuItem {
            text: "Выделить все"
            onTriggered: ++scene.submitted
        }
        EditorialMenuItem {
            text: "Удалить"
            destructive: true
        }
        EditorialMenuItem {
            text: "Недоступное действие"
            enabled: false
        }
    }
    EditorialDialog {
        id: form
        width: 480
        height: 560
        modal: true
        anchors.centerIn: parent
        title: "Параметры операции"
        contentItem: EditorialDialogForm {
            Repeater {
                model: 24
                StyledCheckBox {
                    required property int index
                    objectName: "flag" + index
                    Layout.fillWidth: true
                    text: "Учитывать счёт " + (index + 1)
                }
            }
            StyledTextField {
                objectName: "lastField"
                Layout.fillWidth: true
                placeholderText: "Описание операции"
                maximumLength: 80
            }
            StyledButton {
                objectName: "lastSubmit"
                text: "Сохранить"
                primary: true
                onClicked: {
                    ++scene.submitted;
                    form.close();
                }
            }
        }
    }
    SignalSpy {
        id: accepted
        target: form
        signalName: "accepted"
    }
    SignalSpy {
        id: rejected
        target: form
        signalName: "rejected"
    }
    TestCase {
        name: "EditorialControls"
        when: windowShown
        function init() {
            scene.submitted = 0;
            accepted.clear();
            rejected.clear();
            choice.model = [
                {
                    label: "Без капитализации",
                    value: "none"
                },
                {
                    label: "Ежемесячно",
                    value: "monthly"
                },
                {
                    label: "Ежегодно",
                    value: "yearly"
                }
            ];
            choice.currentIndex = 0;
            form.standardButtons = Dialog.NoButton;
            mouseMove(scene, 1200, 760);
        }
        function cleanup() {
            form.close();
            menu.close();
            choice.popup.close();
        }
        function visualChild(item, name) {
            if (item.objectName === name)
                return item;
            const children = item.children || [];
            for (let i = 0; i < children.length; ++i) {
                const found = visualChild(children[i], name);
                if (found)
                    return found;
            }
            return null;
        }
        function test_choices_readable_with_dark_system_palette() {
            choice.popup.open();
            tryCompare(choice.popup, "opened", true);
            verify(waitForRendering(choice.popup.contentItem));
            for (let i = 0; i < choice.count; ++i) {
                const row = choice.popup.contentItem.itemAtIndex(i);
                verify(row !== null);
                compare(row.contentItem.text, choice.textAt(i));
                compare(row.contentItem.color, Qt.color(row.highlighted || row.hovered ? "#f3eddf" : "#031528"));
            }
            const last = choice.popup.contentItem.itemAtIndex(2);
            mouseClick(last);
            compare(choice.currentValue, "yearly");
            compare(choice.popup.visible, false);
        }
        function test_checkbox_wraps_and_toggles() {
            verify(wrappingCheck.height > 40);
            compare(wrappingCheck.indicator.radius, 0);
            const before = wrappingCheck.checked;
            mouseClick(wrappingCheck, 10, wrappingCheck.height / 2);
            compare(wrappingCheck.checked, !before);
        }
        function test_long_form_scroll_and_keyboard_focus() {
            form.open();
            tryCompare(form, "opened", true);
            verify(waitForRendering(form.contentItem));
            const viewport = form.contentItem.contentItem;
            verify(viewport.contentHeight > viewport.height);
            const flag = visualChild(form.contentItem, "flag0");
            verify(flag !== null);
            mouseClick(flag, 12, flag.height / 2);
            verify(flag.checked);
            const input = visualChild(form.contentItem, "lastField");
            input.forceActiveFocus();
            tryVerify(function () {
                return viewport.contentY > 0;
            });
            keyClick(Qt.Key_A);
            compare(input.text, "a");
            const save = visualChild(form.contentItem, "lastSubmit");
            save.forceActiveFocus();
            wait(20);
            keyClick(Qt.Key_Space);
            compare(scene.submitted, 1);
        }
        function test_long_list_scrolls_and_selects_hidden_option() {
            choice.model = Array.from({
                length: 100
            }, function (_, i) {
                return {
                    label: "Счёт " + i,
                    value: i
                };
            });
            choice.popup.open();
            tryCompare(choice.popup, "opened", true);
            const list = choice.popup.contentItem;
            verify(waitForRendering(list));
            verify(list.contentHeight > list.height);
            verify(choice.popup.height <= 320);
            mouseWheel(list, 40, 40, 0, -120);
            tryVerify(function () {
                return list.contentY > 0;
            });
            list.positionViewAtIndex(50, ListView.Center);
            verify(waitForRendering(list));
            const row = list.itemAtIndex(50);
            verify(row !== null);
            mouseClick(row);
            compare(choice.currentValue, 50);
        }
        function test_standard_dialog_buttons_keep_accept_and_cancel() {
            form.standardButtons = Dialog.Ok | Dialog.Cancel;
            form.open();
            tryCompare(form, "opened", true);
            verify(waitForRendering(form.footer));
            mouseClick(form.footer.standardButton(Dialog.Ok));
            compare(accepted.count, 1);
            form.open();
            tryCompare(form, "opened", true);
            verify(waitForRendering(form.footer));
            mouseClick(form.footer.standardButton(Dialog.Cancel));
            compare(rejected.count, 1);
        }
        function test_context_menu_colors_and_actions() {
            menu.open();
            tryCompare(menu, "opened", true);
            for (let i = 0; i < menu.count; ++i) {
                const item = menu.itemAt(i);
                compare(item.contentItem.color, Qt.color(!item.enabled ? "#59616a" : item.emphasized ? "#f3eddf" : item.destructive ? "#b84932" : "#031528"));
            }
            mouseClick(menu.itemAt(0));
            compare(scene.submitted, 1);
        }
    }
}
