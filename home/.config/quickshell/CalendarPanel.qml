// CalendarPanel.qml — calendar face unfolded FROM the notch.
//
// One month and nothing more: header with month/year plus navigation, weekday
// initials per locale (ShellState.loc.firstDayOfWeek), and a fixed 6-row × 7-
// column grid so the notch height never jumps when the month changes. Today is
// marked with Colors.accent. A calendar for looking at: no notes, no events,
// no holidays.
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool active: ShellState.panel === "calendar"

    // Date ONLY, not time. The shell clock ticks every second, and hanging
    // the grid off it rebuilt 42 Date objects and their 42 delegates
    // ONCE PER SECOND, forever, with the panel closed and per monitor. A
    // "yyyy-MM-dd" string only emits a change when the day changes, which is
    // exactly when the grid has something new to say.
    readonly property string todayKey: Qt.formatDate(ShellState.now, "yyyy-MM-dd")

    property int viewYear: parseInt(root.todayKey.slice(0, 4))
    property int viewMonth: parseInt(root.todayKey.slice(5, 7)) - 1

    readonly property bool isCurrentMonth: root.viewYear === parseInt(root.todayKey.slice(0, 4))
        && root.viewMonth === parseInt(root.todayKey.slice(5, 7)) - 1

    function goToToday() {
        root.viewYear = parseInt(root.todayKey.slice(0, 4));
        root.viewMonth = parseInt(root.todayKey.slice(5, 7)) - 1;
    }

    function prevMonth() {
        if (root.viewMonth === 0) {
            root.viewMonth = 11;
            root.viewYear--;
        } else {
            root.viewMonth--;
        }
    }

    function nextMonth() {
        if (root.viewMonth === 11) {
            root.viewMonth = 0;
            root.viewYear++;
        } else {
            root.viewMonth++;
        }
    }

    // Opening the panel always returns to today and grabs focus so it can
    // close with Escape or change month with the keyboard arrows.
    onActiveChanged: {
        if (root.active) {
            root.goToToday();
            keys.forceActiveFocus();
        }
    }

    // Swallows clicks on empty areas and adds fast month navigation with the wheel
    MouseArea {
        anchors.fill: parent
        onWheel: function (w) {
            if (w.angleDelta.y > 0) root.prevMonth();
            else if (w.angleDelta.y < 0) root.nextMonth();
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.closePanel()
        Keys.onLeftPressed: root.prevMonth()
        Keys.onRightPressed: root.nextMonth()
        Keys.onReturnPressed: if (!root.isCurrentMonth) root.goToToday()
        Keys.onEnterPressed: if (!root.isCurrentMonth) root.goToToday()
    }

    // Fixed 42-cell grid (6 full weeks).
    // The first column always follows ShellState.loc.firstDayOfWeek.
    // Days outside the current month are flagged isCurrentMonth: false
    // to paint them dimmed.
    readonly property var gridCells: {
        const y = root.viewYear;
        const m = root.viewMonth;
        const firstDow = ShellState.loc.firstDayOfWeek;
        const todayY = parseInt(root.todayKey.slice(0, 4));
        const todayM = parseInt(root.todayKey.slice(5, 7)) - 1;
        const todayD = parseInt(root.todayKey.slice(8, 10));

        // Noon, not midnight, on EVERY date built here. Where the spring
        // forward jumps at midnight -Santiago, Beirut, Havana- that day's 00:00
        // does NOT EXIST, and the engine resolves it as 23:00 the day before:
        // the changeover day drops off the grid and the previous one shows
        // twice. In Madrid the jump is at 02:00 and never shows, but this repo
        // is public.
        const firstOfMonth = new Date(y, m, 1, 12).getDay();
        const leadDays = (firstOfMonth - firstDow + 7) % 7;

        const cells = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(y, m, 1 - leadDays + i, 12);
            const cellY = d.getFullYear();
            const cellM = d.getMonth();
            const cellD = d.getDate();
            cells.push({
                day: cellD,
                isCurrentMonth: cellM === m,
                isToday: cellY === todayY && cellM === todayM && cellD === todayD
            });
        }
        return cells;
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: 21
            rightMargin: 21
            topMargin: 20
            bottomMargin: 16
        }
        spacing: 0

        // ─────────────── header: month, year, controls ───────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Clicking the title while on another month returns to today
            Text {
                text: ShellState.capitalize(new Date(root.viewYear, root.viewMonth, 1, 12).toLocaleDateString(ShellState.loc, "MMMM yyyy"))
                color: "#ffffff"
                font.family: Appearance.fontUI
                font.pixelSize: 15
                font.weight: Font.DemiBold

                MouseArea {
                    anchors.fill: parent
                    cursorShape: !root.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: !root.isCurrentMonth
                    onClicked: root.goToToday()
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                // "Today" button: only appears off the current month so no useless button sits around
                Rectangle {
                    id: todayBtn
                    visible: !root.isCurrentMonth
                    height: 26
                    width: todayLbl.implicitWidth + 16
                    radius: Appearance.radS
                    color: todayMa.pressed
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.35)
                        : todayMa.containsMouse
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.20)
                        : Qt.rgba(1, 1, 1, 0.07)
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                    scale: todayMa.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }

                    Text {
                        id: todayLbl
                        anchors.centerIn: parent
                        text: I18n.tr("Today")
                        color: Colors.accent
                        font.family: Appearance.fontUI
                        font.pixelSize: Appearance.fsXS
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: todayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToToday()
                    }
                }

                // Previous month arrow
                Rectangle {
                    id: prevBtn
                    width: 26
                    height: 26
                    radius: Appearance.radS
                    color: prevMa.pressed
                        ? Qt.rgba(1, 1, 1, 0.16)
                        : prevMa.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.10)
                        : Qt.rgba(1, 1, 1, 0.05)
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                    scale: prevMa.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: prevMa.containsMouse ? "#ffffff" : "#c0c0c0"
                        font.family: Appearance.fontUI
                        font.pixelSize: 18
                        Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                    }

                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevMonth()
                    }
                }

                // Next month arrow
                Rectangle {
                    id: nextBtn
                    width: 26
                    height: 26
                    radius: Appearance.radS
                    color: nextMa.pressed
                        ? Qt.rgba(1, 1, 1, 0.16)
                        : nextMa.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.10)
                        : Qt.rgba(1, 1, 1, 0.05)
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                    scale: nextMa.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: nextMa.containsMouse ? "#ffffff" : "#c0c0c0"
                        font.family: Appearance.fontUI
                        font.pixelSize: 18
                        Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                    }

                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextMonth()
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 14 }

        // ─────────────── weekday initials row ───────────────
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            Repeater {
                model: 7
                Item {
                    width: 44
                    height: 18
                    Text {
                        anchors.centerIn: parent
                        text: ShellState.loc.dayName((ShellState.loc.firstDayOfWeek + index) % 7, Locale.NarrowFormat).toUpperCase()
                        color: "#707070"
                        font.family: Appearance.fontUI
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 8 }

        // ─────────────── 6-row × 7-column grid ───────────────
        Grid {
            Layout.fillWidth: true
            columns: 7
            rows: 6
            rowSpacing: 4
            columnSpacing: 0

            Repeater {
                model: root.gridCells

                Item {
                    id: cell
                    required property var modelData
                    width: 44
                    height: 32

                    // Accent circle for today
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: Colors.accent
                        visible: cell.modelData.isToday
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(cell.modelData.day)
                        font.family: Appearance.fontUI
                        font.pixelSize: 13
                        font.weight: cell.modelData.isToday ? Font.Bold : Font.Normal
                        font.features: ({ "tnum": 1 })
                        color: cell.modelData.isToday
                            ? Colors.bg
                            : cell.modelData.isCurrentMonth
                            ? "#ffffff"
                            : Qt.rgba(1, 1, 1, 0.22)
                    }
                }
            }
        }
    }
}
