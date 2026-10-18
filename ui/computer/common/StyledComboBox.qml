import QtQuick
import QtQuick.Controls
import "EditorialStyle.js" as Appearance

ComboBox {
    id: control
    readonly property bool editorial: Appearance.desktop

    property color appTextColor: "#031528"
    property color appMutedColor: editorial ? "#59616a" : "#687483"
    property color appPanelColor: editorial ? "#f3eddf" : "#FFFFF8"
    property color appSoftColor: editorial ? "#f3eddf" : "#FFFFF0"
    property color appLineColor: editorial ? "#bbb5a8" : "#D8D7C7"
    property color appAccentColor: editorial ? "#031528" : "#315C9B"
    property color appHoverColor: editorial ? "#e9e4d8" : "#E4E8F1"
    property bool neo: false
    readonly property int neoPressShift: 0
    property int controlHeight: editorial ? 48 : 44
    property string emptyText: ""

    hoverEnabled: true
    implicitHeight: controlHeight
    leftPadding: editorial ? 0 : 14
    rightPadding: editorial ? 28 : 42
    font.family: editorial ? "Arimo" : "Commissioner"
    font.pixelSize: editorial ? 16 : 14

    contentItem: Text {
        text: control.count > 0 ? control.displayText : control.emptyText
        color: control.enabled ? control.appTextColor : control.appMutedColor
        transform: Translate {
            y: control.neoPressShift
        }
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Drawn rather than typed: the chevron glyphs are missing from the phone's fonts
    indicator: Canvas {
        readonly property bool open: control.popup.visible
        readonly property color strokeColor: control.enabled ? control.appAccentColor : control.appMutedColor
        x: control.width - width - 15
        y: (control.height - height) / 2 - 1
        width: 12
        height: 8
        transform: Translate {
            y: control.neoPressShift
        }
        onOpenChanged: requestPaint()
        onStrokeColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.strokeStyle = strokeColor;
            context.lineWidth = 2;
            context.lineCap = "round";
            context.lineJoin = "round";
            context.beginPath();
            if (open) {
                context.moveTo(1, 7);
                context.lineTo(6, 2);
                context.lineTo(11, 7);
            } else {
                context.moveTo(1, 1);
                context.lineTo(6, 6);
                context.lineTo(11, 1);
            }
            context.stroke();
        }
    }

    background: Rectangle {
        transform: Translate {
            y: control.neoPressShift
        }
        radius: control.editorial ? 0 : control.neo ? 8 : 11
        opacity: control.enabled ? 1 : 0.62
        color: control.editorial ? "transparent" : control.neo ? (control.hovered || control.pressed || control.popup.visible ? control.appHoverColor : control.appPanelColor) : control.pressed || control.popup.visible ? control.appPanelColor : control.hovered ? control.appHoverColor : control.appSoftColor
        border.width: control.editorial ? 0 : 1
        border.color: control.appLineColor
        Rectangle {
            visible: control.editorial
            y: parent.height - 1
            width: parent.width
            height: 1
            color: control.popup.visible || control.activeFocus ? control.appAccentColor : control.appLineColor
        }
    }

    delegate: ItemDelegate {
        id: optionDelegate
        required property int index
        width: control.popup.availableWidth
        height: control.editorial ? 48 : 40
        leftPadding: 12
        rightPadding: 12
        hoverEnabled: true
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: control.textAt(optionDelegate.index)
            color: (control.editorial || control.neo) && (optionDelegate.highlighted || optionDelegate.hovered) ? control.appPanelColor : control.appTextColor
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: control.editorial ? 0 : 8
            color: optionDelegate.highlighted || optionDelegate.hovered ? (control.editorial || control.neo ? control.appAccentColor : control.appHoverColor) : "transparent"
        }
    }

    popup: Popup {
        y: control.height + (control.editorial ? 4 : 6)
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, control.editorial ? 320 : 260)
        padding: control.editorial ? 4 : 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            spacing: control.editorial ? 0 : 2
            ScrollBar.vertical: StyledScrollBar {
                appAccentColor: control.appAccentColor
                appTrackColor: control.appLineColor
            }
        }

        background: Rectangle {
            radius: control.editorial ? 0 : 12
            color: control.appPanelColor
            border.width: 1
            border.color: control.editorial ? control.appAccentColor : control.appLineColor
        }
    }
}
