pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Detects the distro without assuming every use of this rice is pure Arch.
// The Omarchy mark is its own SVG; the rest use Nerd Font glyphs.
Singleton {
    id: root

    property string id: "linux"
    property string name: "Linux"
    readonly property bool omarchy: id === "omarchy"
    readonly property string glyph: omarchy ? "" : (id === "arch" ? Icons.arch : "")
    readonly property url markSource: omarchy ? Qt.resolvedUrl("assets/omarchy.svg") : ""

    Process {
        running: true
        command: ["bash", "-lc", ". /etc/os-release 2>/dev/null; printf '%s\\t%s\\n' \"${ID:-linux}\" \"${PRETTY_NAME:-Linux}\""]
        stdout: SplitParser {
            onRead: function(line) {
                const pair = line.split("\t");
                if (pair[0]) root.id = pair[0].toLowerCase();
                if (pair[1]) root.name = pair[1];
            }
        }
    }
}
