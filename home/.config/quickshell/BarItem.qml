// BarItem.qml, bar cell: icon + optional text.
// The bar has no background, so glyphs carry a very soft dark outline to
// read the same over light and dark wallpapers. The only background that
// appears is the hover highlight.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property url iconSource: ""
    // Glyph family override: icons live in the Nerd family, except product
    // marks that ship their own (the Encaixe lives in Aroli Mono NF).
    property string iconFontFamily: Appearance.font
    property string label: ""
    property color iconColor: Colors.fg
    // Tint for the iconSource image (brand marks are grayscale SVGs, so
    // without this they never follow the palette). Transparent = untinted,
    // keeping full-color images safe if one is ever passed here.
    property color imageTint: "#00000000"
    property color labelColor: Colors.fg
    property int iconSize: Appearance.fsM
    property int labelSize: Appearance.fsS
    property bool labelBold: false
    property bool active: false
    property bool interactive: true
    property int itemHeight: 24
    property int hpad: 7
    property int gap: 6
    // outline for legibility over any wallpaper
    property color outline: Qt.rgba(0, 0, 0, 0.55)

    readonly property alias hovered: ma.containsMouse

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int dir)             // +1 wheel up, -1 wheel down

    implicitWidth: row.implicitWidth + hpad * 2
    implicitHeight: itemHeight
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.active ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.28)
             : (ma.containsMouse && root.interactive) ? Qt.rgba(0, 0, 0, 0.45)
             : "transparent"
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.gap

        Text {
            visible: root.icon.length > 0 && root.iconSource.toString().length === 0
            text: root.icon
            color: root.iconColor
            font.family: root.iconFontFamily
            font.pixelSize: root.iconSize
            style: Text.Outline
            styleColor: root.outline
            anchors.verticalCenter: parent.verticalCenter
        }
        Image {
            visible: root.iconSource.toString().length > 0
            source: root.iconSource
            width: root.iconSize
            height: root.iconSize
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: root.imageTint.a > 0
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: root.imageTint
            }
        }
        Text {
            visible: root.label.length > 0
            text: root.label
            color: root.labelColor
            font.family: Appearance.font
            font.pixelSize: root.labelSize
            font.bold: root.labelBold
            style: Text.Outline
            styleColor: root.outline
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (m) {
            if (m.button === Qt.RightButton) root.rightClicked();
            else if (m.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked();
        }
        onWheel: function (w) { root.scrolled(w.angleDelta.y > 0 ? 1 : -1); }
    }
}
