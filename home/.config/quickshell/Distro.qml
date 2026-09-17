pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Identifica a distribuição sem supor que todo uso deste rice é Arch puro.
// A marca do Omarchy é um SVG próprio; as demais usam glifos da Nerd Font.
Singleton {
    id: root

    property string id: "arch"
    property string name: "Arch Linux"
    readonly property bool omarchy: id === "omarchy"
    readonly property string glyph: omarchy ? "" : (id === "arch" ? Icons.arch : "")
    readonly property url markSource: omarchy ? Qt.resolvedUrl("assets/omarchy.svg") : ""

    Process {
        running: true
        command: ["bash", "-lc", ". /etc/os-release 2>/dev/null; printf '%s\\t%s\\n' \"${ID:-arch}\" \"${PRETTY_NAME:-Arch Linux}\""]
        stdout: SplitParser {
            onRead: function(line) {
                const pair = line.split("\t");
                if (pair[0]) root.id = pair[0].toLowerCase();
                if (pair[1]) root.name = pair[1];
            }
        }
    }
}
