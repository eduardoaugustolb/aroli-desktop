// MediaPanel.qml, vertical player inside the control center (Super+D).
//
// The layout follows a single column: hero cover art, title and
// artist, progress, controls, and lyrics when available (spectrum otherwise).
// That way the player reads not as a horizontal card wedged into the control
// center, but as its own face inside the expanded panel.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root
    readonly property color accent: ShellState.mediaAccent

    // ── lyrics (lrclib, no key needed) ────────────────────────────────────
    // One request per track; the spectrum stays put while loading and when
    // nothing is found, so the foot of the panel never jumps.
    property var lyricLines: []   // [{t: seconds | -1, text}]
    property bool lyricSynced: false
    property string lyricState: "idle" // idle|ready|none
    property var lyricXhr: null
    readonly property string trackKey: ShellState.player
        ? ((ShellState.player.trackArtist || "") + " — " + (ShellState.player.trackTitle || "")) : ""
    onTrackKeyChanged: fetchLyrics()

    // Largest timestamp at or before the playhead; -1 for plain lyrics.
    readonly property int lyricCurrent: {
        if (!root.lyricSynced || root.lyricLines.length === 0) return -1;
        const p = ShellState.pos;
        let idx = -1;
        for (let i = 0; i < root.lyricLines.length; i++) {
            if (root.lyricLines[i].t <= p) idx = i; else break;
        }
        return idx;
    }

    function parseLrc(text) {
        const out = [];
        const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        const rows = text.split("\n");
        for (let r = 0; r < rows.length; r++) {
            const times = rows[r].match(re);
            if (!times) continue;
            const lyric = rows[r].replace(re, "").trim();
            if (!lyric) continue;
            for (let k = 0; k < times.length; k++) {
                const m = /\[(\d+):(\d+(?:\.\d+)?)\]/.exec(times[k]);
                out.push({ t: parseInt(m[1], 10) * 60 + parseFloat(m[2]), text: lyric });
            }
        }
        out.sort(function (a, b) { return a.t - b.t; });
        return out;
    }

    function fetchLyrics() {
        if (root.lyricXhr) { try { root.lyricXhr.abort(); } catch (e) {} root.lyricXhr = null; }
        const p = ShellState.player;
        const title = p ? (p.trackTitle || "") : "";
        const artist = p ? (p.trackArtist || "") : "";
        root.lyricLines = [];
        root.lyricSynced = false;
        root.lyricState = "idle";
        if (!title) { root.lyricState = "none"; return; }
        const q = "https://lrclib.net/api/get?track_name=" + encodeURIComponent(title)
            + (artist ? "&artist_name=" + encodeURIComponent(artist) : "")
            + (ShellState.len > 0 ? "&duration=" + Math.round(ShellState.len) : "");
        const xhr = new XMLHttpRequest();
        root.lyricXhr = xhr;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            // The panel may be gone (hot reload) while a request flies:
            // a dead component resolves its own id to null.
            if (!root || xhr !== root.lyricXhr) return;
            root.lyricXhr = null;
            if (xhr.status !== 200) { root.lyricState = "none"; return; }
            try {
                const d = JSON.parse(xhr.responseText);
                if (d.syncedLyrics) {
                    const lines = parseLrc(d.syncedLyrics);
                    if (lines.length) {
                        root.lyricLines = lines;
                        root.lyricSynced = true;
                        root.lyricState = "ready";
                        return;
                    }
                }
                if (d.plainLyrics) {
                    const lines = [];
                    const rows = d.plainLyrics.split("\n");
                    for (let r = 0; r < rows.length; r++)
                        lines.push({ t: -1, text: rows[r].trim() });
                    while (lines.length && !lines[0].text) lines.shift();
                    while (lines.length && !lines[lines.length - 1].text) lines.pop();
                    if (lines.length) {
                        root.lyricLines = lines;
                        root.lyricSynced = false;
                        root.lyricState = "ready";
                        return;
                    }
                }
            } catch (e) {}
            root.lyricState = "none";
        };
        xhr.open("GET", q);
        xhr.send();
    }

    Component.onCompleted: fetchLyrics()

    // The whole background swallows clicks so a gap between controls never
    // reaches any action behind the panel.
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: 22
            rightMargin: 22
            topMargin: 20
            bottomMargin: 18
        }
        spacing: 10

        // ── rounded cover art, no rings (Apple Music-like) ────────────────────
        // Soft shadow baked into the mask effect: depth without drawing
        // attention away from the cover.
        Item {
            id: artStage
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 166
            Layout.preferredHeight: 166

            Image {
                id: coverImage
                anchors.centerIn: parent
                width: 146; height: 146
                source: (ShellState.player && ShellState.player.trackArtUrl)
                    ? ShellState.player.trackArtUrl : ""
                sourceSize.width: 292
                sourceSize.height: 292
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                visible: false
            }

            // clip:true crops to a rectangle even when the parent has radius.
            // MultiEffect uses this real mask so the cover keeps the
            // rounded corners (mask radius = cover radius).
            Item {
                id: coverMask
                width: coverImage.width
                height: coverImage.height
                layer.enabled: true
                layer.smooth: true
                visible: false
                Rectangle { anchors.fill: parent; radius: 28 }
            }
            MultiEffect {
                anchors.fill: coverImage
                source: coverImage
                visible: coverImage.status === Image.Ready
                antialiasing: true
                maskEnabled: true
                maskSource: coverMask
                maskSpreadAtMin: 1.0
                maskThresholdMin: 0.5
                maskThresholdMax: 1.0
            }

            Text {
                anchors.centerIn: parent
                visible: coverImage.status !== Image.Ready
                text: "󰎈"
                color: root.accent
                font.family: Appearance.font
                font.pixelSize: Appearance.fsXXL
                Behavior on color { ColorAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
            }
        }

        // ── title and artist ────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: ShellState.player
                    ? (ShellState.player.trackTitle || I18n.tr("Nothing playing"))
                    : I18n.tr("Nothing playing")
                color: Colors.inkHi
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsL
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: ShellState.player ? (ShellState.player.trackArtist || "") : ""
                color: Colors.inkMid
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsS
            }
        }

        // ── progress: quiet, but clickable to seek ──────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 25
            Layout.topMargin: 2

            Rectangle {
                id: seek
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1 }
                height: 4; radius: 2
                color: "#2c2c2c"

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: ShellState.len > 0
                        ? seek.width * Math.max(0, Math.min(1, ShellState.pos / ShellState.len)) : 0
                    color: root.accent
                    Behavior on color { ColorAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: Appearance.mTick } }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Appearance.hitPad
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function (m) {
                        if (ShellState.player && ShellState.len > 0)
                            ShellState.player.position = (m.x / width) * ShellState.len;
                    }
                }
            }

            Text {
                anchors { left: parent.left; bottom: parent.bottom }
                text: ShellState.fmt(ShellState.pos)
                color: Colors.inkLo
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsCaption
                font.features: ({ "tnum": 1 })
            }
            Text {
                anchors { right: parent.right; bottom: parent.bottom }
                text: ShellState.fmt(ShellState.len)
                color: Colors.inkLo
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsCaption
                font.features: ({ "tnum": 1 })
            }
        }

        // ── previous / pause / next ─────────────────────────────────
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 52
            spacing: 22

            Repeater {
                model: 3
                Item {
                    id: transport
                    required property int index
                    width: index === 1 ? 52 : 38
                    height: 52

                    Rectangle {
                        anchors.centerIn: parent
                        visible: transport.index === 1
                        width: 48; height: 48; radius: 24
                        color: transportMa.containsMouse
                            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.34)
                            : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
                        scale: transportMa.pressed ? 0.90 : 1
                        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                        Behavior on scale { SpringAnimation { spring: Appearance.sprTight; damping: Appearance.dmpTight; epsilon: Appearance.eppScale } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: transport.index === 0 ? Icons.prev
                            : transport.index === 1
                                ? (ShellState.player && ShellState.player.isPlaying ? Icons.pause : Icons.play)
                                : Icons.next
                        color: transportMa.containsMouse ? root.accent : Colors.inkHi
                        font.family: Appearance.font
                        font.pixelSize: transport.index === 1 ? 24 : 19
                        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                    }

                    MouseArea {
                        id: transportMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!ShellState.player) return;
                            if (transport.index === 0) ShellState.player.previous();
                            else if (transport.index === 1)
                                ShellState.player.isPlaying ? ShellState.player.pause() : ShellState.player.play();
                            else ShellState.player.next();
                        }
                    }
                }
            }
        }

        // ── lyrics when found, spectrum otherwise ─────────────────────────────
        // Same slot either way, so the foot never jumps: the wave is also
        // the loading state while the request flies.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 96

            ListView {
                id: lyricList
                anchors.fill: parent
                visible: root.lyricState === "ready"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                model: root.lyricLines
                currentIndex: root.lyricCurrent
                // A linha atual fica sempre centrada (quando há letra acima
                // para permitir): StrictlyEnforceRange cola o highlight na
                // faixa central, e a duração fixa dá o deslize de ~0,5s a
                // cada verso, sem salto. No início, sem linhas acima, ela
                // fica no topo até dar para centralizar.
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height / 2 - 16
                preferredHighlightEnd: height / 2 + 16
                highlightMoveDuration: Appearance.mFollow
                spacing: 7
                clip: true
                delegate: Text {
                    width: lyricList.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: modelData.text
                    color: index === lyricList.currentIndex ? Colors.inkHi : Colors.inkLo
                    Behavior on color { ColorAnimation { duration: Appearance.mTint; easing.type: Easing.OutCubic } }
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsM
                }
            }

            Item {
                anchors.centerIn: parent
                visible: root.lyricState !== "ready"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                width: ShellState.bands * 13 - 7
                height: 58

                Repeater {
                    model: ShellState.bands
                    Rectangle {
                        required property int index
                        x: index * 13
                        width: 6
                        radius: 3
                        antialiasing: true
                        color: root.accent
                        Behavior on color { ColorAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                        height: Math.max(6, 58 * (ShellState.levels[index] || 0))
                        y: (58 - height) / 2
                    }
                }
            }
        }
    }
}
