// SettingsShortcuts.qml — los atajos de teclado, leídos en vivo de
// ~/.config/hypr/hyprland.conf.
//
// POR QUÉ LEERLOS Y NO ESCRIBIRLOS A MANO: una lista escrita aquí se
// desincroniza el primer día que toques un bind. Esto parsea el fichero de
// verdad (resolviendo $mainMod) y se recarga solo cuando cambia, así que no
// puede mentir.
//
// Esta es YA la única lista de atajos: Super+K abría un rofi aparte
// (~/.config/hypr/list_keybinds.sh) que hacía este mismo parseo del mismo
// fichero, o sea dos listas que solo coincidían mientras nadie tocara ninguna.
// Desde 2026-08-19 esa tecla entra directamente aquí (GlobalShortcut
// "keybinds" en SettingsWindow.qml) y el script se archivó.
//
// De momento es SOLO LECTURA: reasignar teclas implicaría reescribir el .conf
// con el riesgo de destrozar comentarios y orden, y ese fichero es la fuente de
// verdad del rice.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root

    property string note: I18n.tr("Read from ~/.config/hypr/hyprland.conf. Super+K opens this same list.")
    property var binds: []
    readonly property int matchCount: cShell.visibleRows + cWin.visibleRows + cWs.visibleRows
        + cApps.visibleRows + cSys.visibleRows

    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    onVisibleChanged: if (visible) contentY = 0

    FileView {
        id: conf
        path: ShellState.home + "/.config/hypr/hyprland.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.binds = root.parseConf(text())
    }

    // La lista se construye UNA vez, al leer el fichero: no es un binding.
    // Como los rótulos de tecla y de dispatcher SÍ están traducidos, al
    // cambiar de idioma hay que volver a parsear o se quedarían en el
    // idioma anterior hasta que alguien tocara hyprland.conf.
    Connections {
        target: I18n
        function onLangChanged() {
            const t = conf.text();
            if (t && t.length > 0) root.binds = root.parseConf(t);
        }
    }

    // ─────────── parseo ───────────
    function parseConf(txt) {
        if (!txt || txt.length === 0) return [];
        const vars = {};
        const out = [];
        const lines = txt.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            let m = line.match(/^\$(\w+)\s*=\s*(.+)$/);
            if (m) { vars[m[1]] = m[2].split("#")[0].trim(); continue; }
            m = line.match(/^(bind[a-z]*)\s*=\s*(.+)$/);
            if (!m) continue;

            let rest = m[2];
            let comment = "";
            const h = rest.indexOf("#");
            if (h >= 0) { comment = rest.slice(h + 1).trim(); rest = rest.slice(0, h); }

            const parts = rest.split(",");
            if (parts.length < 3) continue;
            let mods = parts[0].trim();
            const key = parts[1].trim();
            const disp = parts[2].trim();
            const args = parts.slice(3).join(",").trim();
            for (const k in vars) mods = mods.replace("$" + k, vars[k]);

            out.push({
                combo: root.comboLabel(mods, key),
                // El comentario viene del propio hyprland.conf, en castellano, y
                // se traduce aqui: asi la config de Hyprland -que es de Eduardo Augusto y
                // esta en castellano a proposito- no hay que tocarla para cambiar
                // de idioma. La clave del diccionario es el comentario literal.
                what: comment.length > 0 ? I18n.tr(comment) : root.dispLabel(disp, args),
                group: root.groupOf(disp, args)
            });
        }
        return out;
    }

    readonly property var modNames: ({
        "SUPER": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "CONTROL": "Ctrl", "ALT": "Alt"
    })
    readonly property var keyNames: ({
        "comma": ",", "period": ".", "slash": "/", "space": I18n.tr("Space"), "TAB": "Tab",
        "Print": I18n.tr("Print Scr"), "return": I18n.tr("Enter"), "escape": "Esc",
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse_down": I18n.tr("wheel ↓"), "mouse_up": I18n.tr("wheel ↑"),
        "mouse:272": I18n.tr("left click"), "mouse:273": I18n.tr("right click"),
        "XF86AudioRaiseVolume": I18n.tr("Volume up"), "XF86AudioLowerVolume": I18n.tr("Volume down"),
        "XF86AudioMute": I18n.tr("Mute"), "XF86AudioMicMute": I18n.tr("Mute mic"),
        "XF86AudioNext": I18n.tr("Next"), "XF86AudioPrev": I18n.tr("Previous"),
        "XF86AudioPlay": I18n.tr("Play"), "XF86AudioPause": I18n.tr("Pause"),
        "XF86MonBrightnessUp": I18n.tr("Brightness up"), "XF86MonBrightnessDown": I18n.tr("Brightness down"),
        "XF86PowerOff": I18n.tr("Power button")
    })

    function comboLabel(mods, key) {
        const out = [];
        const ms = mods.split(/\s+/);
        for (let i = 0; i < ms.length; i++) {
            const t = ms[i].trim().toUpperCase();
            if (t.length === 0) continue;
            out.push(root.modNames[t] !== undefined ? root.modNames[t] : ms[i].trim());
        }
        const k = key.trim();
        out.push(root.keyNames[k] !== undefined ? root.keyNames[k]
               : (k.length === 1 ? k.toUpperCase() : k));
        return out.join(" + ");
    }

    readonly property var dispNames: ({
        "killactive": I18n.tr("close the window"), "exit": I18n.tr("quit Hyprland"),
        "togglefloating": I18n.tr("floating on/off"), "fullscreen": I18n.tr("fullscreen"),
        "pseudo": "pseudo-tile", "togglesplit": I18n.tr("change the split"),
        "movefocus": I18n.tr("move the focus"), "movewindow": I18n.tr("move the window"),
        "resizeactive": I18n.tr("resize"), "workspace": I18n.tr("go to workspace"),
        "movetoworkspace": I18n.tr("send to workspace"), "layoutmsg": "layout",
        "togglespecialworkspace": I18n.tr("special workspace")
    })

    function dispLabel(disp, args) {
        if (disp === "exec") return args;
        if (disp === "global") return args.replace("quickshell:", "");
        const base = root.dispNames[disp] !== undefined ? root.dispNames[disp] : disp;
        return args.length > 0 ? base + " " + args : base;
    }

    function groupOf(disp, args) {
        if (disp === "global") return "shell";
        if (disp === "exec") return "apps";
        if (disp.indexOf("workspace") >= 0) return "ws";
        if (disp.indexOf("window") >= 0 || disp.indexOf("focus") >= 0
            || disp === "killactive" || disp === "togglefloating"
            || disp === "fullscreen" || disp === "pseudo" || disp === "togglesplit"
            || disp === "layoutmsg" || disp === "resizeactive") return "win";
        return "sys";
    }

    function ofGroup(g) {
        const out = [];
        for (let i = 0; i < root.binds.length; i++) if (root.binds[i].group === g) out.push(root.binds[i]);
        return out;
    }

    ColumnLayout {
        id: col
        width: root.width - 48
        x: 24
        y: 16
        spacing: 10

        SettingsControls.Card_ {
            id: cShell
            title: I18n.tr("THE SHELL")
            Repeater {
                model: root.ofGroup("shell")
                onItemAdded: cShell.recount()
                onItemRemoved: cShell.recount()
                KeyRow {}
            }
        }

        SettingsControls.Card_ {
            id: cWin
            title: I18n.tr("WINDOWS")
            Repeater {
                model: root.ofGroup("win")
                onItemAdded: cWin.recount()
                onItemRemoved: cWin.recount()
                KeyRow {}
            }
        }

        SettingsControls.Card_ {
            id: cWs
            title: I18n.tr("WORKSPACES")
            Repeater {
                model: root.ofGroup("ws")
                onItemAdded: cWs.recount()
                onItemRemoved: cWs.recount()
                KeyRow {}
            }
        }

        SettingsControls.Card_ {
            id: cApps
            title: I18n.tr("APPS AND SCRIPTS")
            Repeater {
                model: root.ofGroup("apps")
                onItemAdded: cApps.recount()
                onItemRemoved: cApps.recount()
                KeyRow {}
            }
        }

        SettingsControls.Card_ {
            id: cSys
            title: I18n.tr("SYSTEM")
            Repeater {
                model: root.ofGroup("sys")
                onItemAdded: cSys.recount()
                onItemRemoved: cSys.recount()
                KeyRow {}
            }
        }

        SettingsControls.Note_ {
            Layout.topMargin: 10
            visible: root.binds.length === 0
            text: I18n.tr("No shortcuts could be read from hyprland.conf.")
        }

        SettingsControls.Note_ {
            Layout.topMargin: 10
            visible: root.binds.length > 0 && ShellState.settingsQuery.length > 0
                     && !cShell.visible && !cWin.visible && !cWs.visible && !cApps.visible && !cSys.visible
            text: I18n.tr("No shortcut matches “{0}”.", ShellState.settingsQuery)
        }
    }

    // ─────────── fila de atajo ───────────
    component KeyRow: Rectangle {
        id: kr
        required property var modelData

        readonly property bool isSettingsRow: true
        readonly property bool matches: ShellState.settingsMatch(kr.modelData.combo, kr.modelData.what)
        function _recount() {
            let p = kr.parent;
            while (p) { if (p.isSettingsCard) { p.recount(); return; } p = p.parent; }
        }
        onMatchesChanged: kr._recount()
        Component.onCompleted: kr._recount()

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        visible: kr.matches
        radius: Appearance.radS
        color: krHover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

        HoverHandler {
            id: krHover
            onHoveredChanged: {
                if (hovered) ShellState.settingsHint = kr.modelData.what;
                else if (ShellState.settingsHint === kr.modelData.what) ShellState.settingsHint = "";
            }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 152
                Layout.preferredHeight: 22
                radius: 7
                color: Qt.rgba(1, 1, 1, 0.07)
                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    text: kr.modelData.combo
                    color: "#d6d6d6"
                    elide: Text.ElideRight
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXS
                }
            }

            Text {
                Layout.fillWidth: true
                text: kr.modelData.what
                color: "#9a9a9a"
                elide: Text.ElideRight
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
            }
        }
    }
}
