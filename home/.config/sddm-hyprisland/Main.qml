// hyprisland - SDDM theme replicating the hyprlock island.
//
// Goal: the boot login screen is INDISTINGUISHABLE from the lock
// the notch throws. Every number here comes from ~/.config/hypr/hyprlock.conf;
// if you change one there, change it here. Durations and curves are the ones
// in ~/.config/motion-language.md (PANEL 320, CONTENT 210, RESPONSE 130).
//
// Glyphs go escaped (\u{F033E}) on purpose: they are Nerd Font Private Use
// Area and do not survive every editor. Do not paste them literally.

import QtQuick
import QtQuick.Effects

Item {
    id: root

    // Focus is critical: if the field never gets it, there is no way in.
    // forceActiveFocus() in Component.onCompleted is NOT enough - the item is
    // not yet hung under the window and the call is silently lost. Hence
    // focus: true here, the Timer retry, and key forwarding.
    focus: true
    Keys.forwardTo: [password]

    // ---- Palette: mirror of ~/.cache/wal/colors-hyprlock.conf -----------------
    // login-sync.sh writes the accent to /var/lib/sddm-hyprisland/accent
    // every time the wallpaper changes. NOT readonly on purpose: it is read
    // off disk at boot (see Component.onCompleted) and assigned. What
    // theme.conf carries is only the starting point -the theme installer seeds
    // it with the current accent- so the color is not seen jumping as the
    // island comes in. The rest is fixed, same as in the notch: the surface
    // is black and pywal only provides the accent.
    property color accent:              config.accent || "#8cd8c2"

    // Login language. Comes from theme.conf because there is no user session
    // here yet and the rice JSON cannot be read: SDDM runs before anyone's
    // $HOME exists. The installer writes it.
    // If the key is missing, pt-BR, this fork's default.
    readonly property string uiLang:    config.language || "pt-BR"
    readonly property bool english:     uiLang === "en"
    readonly property bool portugueseBrazil: uiLang === "pt-BR"
    readonly property color surface:    Qt.rgba(0, 0, 0, 0.941)   // rgba(000000f0)
    readonly property color surfaceAlt: "#181818"
    readonly property color outline:    Qt.rgba(1, 1, 1, 0.094)   // rgba(ffffff18)
    readonly property color textColor:  "#ffffff"
    readonly property color muted:      "#b0b0b0"
    readonly property color dim:        "#7d7d7d"
    readonly property color okColor:    "#6dbd7a"
    readonly property color warnColor:  "#e0a458"
    readonly property color failColor:  "#e05c5c"

    // ---- Island geometry (hyprlock: shape 520x340, rounding 32) ---------
    readonly property int islandW: 520
    readonly property int islandH: 340
    readonly property int fieldW:  360
    readonly property int fieldH:  50

    // ---- Login state ---------------------------------------------------
    property int  attempts: 0
    property bool checking: false
    property bool failed: false
    // RememberLastUser=true in /etc/sddm.conf, so lastUser usually suffices;
    // firstUser covers first boot and test mode, where it comes empty.
    property string firstUser: ""
    property string userName: userModel.lastUser || firstUser

    Repeater {
        model: userModel
        delegate: Item {
            required property string name
            required property int index
            Component.onCompleted: if (index === 0) root.firstUser = name
        }
    }

    // ---- Sessions -----------------------------------------------------------
    // It used to ALWAYS enter sessionModel.lastIndex with no way to pick
    // another. The day Hyprland failed to start that left the machine locked
    // from the inside: Plasma was installed with no way to reach it without
    // editing the kernel line from the boot manager.
    //
    // The default behavior does NOT change: sessionPick stays -1 while nobody
    // touches the selector, and in that case sddm.login() gets the same old
    // sessionModel.lastIndex.
    //
    // This Repeater draws nothing: it only copies the model names. They read
    // by role ("name", same as in userModel) and not with
    // sessionModel.data(idx, 260) like the `silent` theme does, because that
    // 260 is SDDM's raw enum number and silently breaks if they reorder it.
    property var sessionNames: []
    property int sessionPick: -1
    readonly property int sessionCurrent: sessionPick >= 0 ? sessionPick
                                                           : sessionModel.lastIndex
    readonly property string sessionName:
        (sessionCurrent >= 0 && sessionCurrent < sessionNames.length)
            ? sessionNames[sessionCurrent] : ""

    Repeater {
        id: sessionProbe
        model: sessionModel
        delegate: Item {
            required property string name
            required property int index
            Component.onCompleted: root.rememberSession(index, name)
        }
    }

    // The whole array is reassigned on purpose: mutating one in place does not
    // notify bindings and the label would stay empty.
    function rememberSession(i, sessionTitle) {
        var a = sessionNames.slice();
        while (a.length <= i)
            a.push("");
        a[i] = sessionTitle;
        sessionNames = a;
    }

    // Cycle, don't dropdown. A Qt ComboBox brings its own frame and its own
    // popup over the island, and an open popup can cover the field or steal
    // its focus, the most expensive failure while building this theme. Cycling
    // leaves nothing that can stay open.
    function cycleSession(step) {
        var n = sessionProbe.count;
        if (n <= 1)
            return;
        var cur = (sessionCurrent >= 0 && sessionCurrent < n) ? sessionCurrent : 0;
        sessionPick = (cur + step + n) % n;
        password.forceActiveFocus();      // focus returns to the field, always
    }

    // hyprlock.conf's `softOut` curve. Sibling of the motion language's `shape`:
    // 90% of travel in the first third, long landing.
    readonly property var softOut: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]

    // =========================================================================
    // Background: the current wallpaper, blurred and dimmed just like hyprlock
    // (blur_passes 2, blur_size 4, brightness 0.68, contrast 0.92, vibrancy).
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        // Fixed absolute path: login-sync.sh leaves the background there, running
        // as your user. If the file is missing -freshly installed theme, or
        // wallpaper not yet changed- Qt flags status Error and we fall to the one
        // inside the theme, the last published with sudo.
        source: "file:///var/lib/sddm-hyprisland/current.jpg"
        onStatusChanged: if (status === Image.Error && source != fallback)
                             source = fallback
        readonly property url fallback: config.background || "backgrounds/current.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blur: 1.0
        blurMax: 40
        blurMultiplier: 1.0
        brightness: -0.32     // hyprlock brightness 0.68 (multiplier)
        contrast: -0.08       // hyprlock contrast 0.92
        saturation: 0.14      // hyprlock vibrancy 0.14
    }

    // =========================================================================
    // The island
    // =========================================================================

    // Shadow (hyprlock: shadow_passes 3, shadow_size 18, rgba(000000a6)).
    // Drawn as a gradient of rings, not with MultiEffect, on purpose:
    // a layer.effect clips the shadow to the item edge, and feeding it from
    // a `visible: false` source gave a LIGHT GRAY halo instead of a shadow.
    // 1 px rings with decreasing alpha: predictable, no weird effects.
    Repeater {
        model: 18                                  // shadow_size
        delegate: Rectangle {
            required property int index
            anchors.centerIn: island
            anchors.verticalCenterOffset: 6
            width: island.width + (index + 1) * 2
            height: island.height + (index + 1) * 2
            radius: island.radius + index + 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.65 * Math.pow(1 - index / 18, 2))
            opacity: island.opacity
        }
    }

    Rectangle {
        id: island
        anchors.centerIn: parent
        width: root.islandW
        height: root.islandH
        radius: 32
        color: root.surface
        border.width: 1
        border.color: root.outline

        // PANEL enters: 320 ms.
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.Bezier
                easing.bezierCurve: root.softOut
            }
        }

        // ---- Lock medallion (42x42, +130 above center) --------------
        Rectangle {
            width: 42
            height: 42
            radius: 21
            color: root.surfaceAlt
            border.width: 1
            border.color: root.accent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -130

            Text {
                anchors.centerIn: parent
                text: "\u{F033E}"                     // nf-md-lock
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                color: root.accent
            }
        }

        // ---- Clock (68 px, tabular figures so they don't dance) -------------
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -58
            font.family: "Adwaita Sans"
            font.pixelSize: 68
            font.features: ({ "tnum": 1 })
            color: root.textColor
            text: Qt.formatDateTime(new Date(), "HH:mm")
        }

        // ---- Date in Spanish, independent of system locale ---------
        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -4
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            color: root.muted
            text: root.localDate()
        }

        // ---- Pill field --------------------------------------------------
        Rectangle {
            id: field
            width: root.fieldW
            height: root.fieldH
            radius: height / 2                        // hyprlock rounding -1
            color: root.surfaceAlt
            border.width: 2                           // outline_thickness
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 58

            // The border color IS the message: accent at rest, amber on
            // caps lock, green while checking, red on failure.
            border.color: root.checking ? root.okColor
                        : root.failed ? root.failColor
                        : keyboard.capsLock ? root.warnColor
                        : root.accent

            Behavior on border.color {
                ColorAnimation {
                    duration: 130                     // RESPONSE
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.softOut
                }
            }

            // Captures keystrokes; dots are hand-drawn below to nail the
            // hyprlock size (dots_size 0.20, spacing 0.38).
            TextInput {
                id: password
                anchors.fill: parent
                focus: true
                echoMode: TextInput.Password
                passwordCharacter: " "
                color: "transparent"
                selectionColor: "transparent"
                enabled: !root.checking

                onTextChanged: {
                    root.failed = false;
                }

                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.doLogin();
                        event.accepted = true;
                    }
                    // Keyboard path for the selector, in case the mouse does
                    // not respond: F1 goes to the next session, Shift+F1 to the
                    // previous. F1 types nothing, so it cannot end up inside
                    // the password.
                    if (event.key === Qt.Key_F1) {
                        root.cycleSession((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                        event.accepted = true;
                    }
                }
            }

            // Text state, centered, stands in for the placeholder.
            Text {
                anchors.centerIn: parent
                font.family: "Adwaita Sans"
                font.pixelSize: 14
                visible: text !== ""
                color: root.checking ? root.okColor
                     : root.failed ? root.failColor
                     : Qt.rgba(1, 1, 1, 0.55)         // placeholder alpha 55 %
                text: root.checking ? (root.english ? "Checking…" : root.portugueseBrazil ? "Verificando…" : "Comprobando…")
                    : root.failed ? (root.english ? "No match · attempt " : root.portugueseBrazil ? "Não confere · tentativa " : "No coincide · intento ") + root.attempts
                    : password.text.length === 0 ? (root.english ? "Enter your password" : root.portugueseBrazil ? "Digite sua senha" : "Escribe tu contraseña")
                    : ""
            }

            // The dots. Diameter = 0.20 * height, gap = 0.38 * diameter.
            Row {
                anchors.centerIn: parent
                spacing: root.fieldH * 0.20 * 0.38
                visible: !root.checking && !root.failed && password.text.length > 0

                Repeater {
                    model: password.text.length
                    delegate: Rectangle {
                        width: root.fieldH * 0.20
                        height: width
                        radius: width / 2
                        color: root.textColor

                        // CONTENT enters: 210 ms.
                        scale: 0
                        Component.onCompleted: scale = 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: 210
                                easing.type: Easing.Bezier
                                easing.bezierCurve: root.softOut
                            }
                        }
                    }
                }
            }
        }

        // ---- Footer: identity left, battery right ------------
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -154
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 124
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: root.dim
            text: "\u{F0004}  " + root.userName      // nf-md-account
        }

        Text {
            id: batteryLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 154
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 124
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: root.dim
            text: ""
        }

        // ---- Session selector: the footer's third datum ----------------------
        // Sits on the SAME row as user and battery (offset 124), with the same
        // font, same size, same gray. 248 free px between those two, so it costs
        // neither a pixel of height nor a new line: the footer goes from two
        // stray data to a row of three.
        //
        // If the model yielded no name, this never draws and the island stays
        // EXACTLY as it was. That is the failure mode we want.
        Text {
            id: sessionLabel
            visible: root.sessionName !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 124
            // Width cap in case some .desktop ships a marathon name:
            // before touching user or battery, it clips.
            width: Math.min(implicitWidth, 232)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            // The chevron only appears if there is somewhere to go. With a single
            // session this is data, not a button, and must not hint otherwise.
            text: "\u{F0379}  " + root.sessionName          // nf-md-monitor
                + (sessionProbe.count > 1 ? "  \u{F0140}" : "")   // nf-md-chevron_down
            color: sessionArea.containsMouse ? root.accent : root.dim

            Behavior on color {
                ColorAnimation {
                    duration: 130                 // RESPONSE
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.softOut
                }
            }

            MouseArea {
                id: sessionArea
                anchors.fill: parent
                anchors.margins: -8               // slightly larger click target
                enabled: sessionProbe.count > 1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function (mouse) {
                    root.cycleSession(mouse.button === Qt.RightButton ? -1 : 1);
                }
            }
        }
    }

    // =========================================================================
    // Clocks and data
    // =========================================================================
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clock.text = Qt.formatDateTime(new Date(), "HH:mm");
            dateLabel.text = root.localDate();
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refreshBattery()
    }

    // Same format as ~/.config/hypr/scripts/lock-info.sh, for the same reason:
    // the session runs with LC_TIME=C but the UI speaks Spanish.
    //
    // In English that table is NOT reused nor is the session locale trusted:
    // an explicit en_GB Qt locale is requested. Depending on LC_TIME=C would
    // give the same result today, but the day someone touches SDDM's environment
    // the date would change language with nobody having touched the theme.
    function localDate() {
        var d = new Date();
        if (root.english)
            return d.toLocaleDateString(Qt.locale("en_GB"), "dddd") + " · " +
                   d.toLocaleDateString(Qt.locale("en_GB"), "d MMMM");
        if (root.portugueseBrazil)
            return d.toLocaleDateString(Qt.locale("pt_BR"), "dddd") + " · " +
                   d.toLocaleDateString(Qt.locale("pt_BR"), "d 'de' MMMM");
        var days = ["Domingo", "Lunes", "Martes", "Miércoles",
                    "Jueves", "Viernes", "Sábado"];
        var months = ["enero", "febrero", "marzo", "abril", "mayo", "junio",
                      "julio", "agosto", "septiembre", "octubre",
                      "noviembre", "diciembre"];
        return days[d.getDay()] + " · " + d.getDate() +
               " de " + months[d.getMonth()];
    }

    // NOTE: QML's XMLHttpRequest **does not support sync mode**. With
    // open(..., false) send() throws "Error: Invalid state" and you are left
    // with no data and no clue. Every file reader here goes by callback.
    function readFile(path, done) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE)
                done(xhr.responseText ? xhr.responseText.trim() : "");
        };
        try {
            xhr.open("GET", "file://" + path, true);
            xhr.send();
        } catch (e) {
            done("");
        }
    }

    // The battery is discovered once, then only its data is reread.
    property string batteryPath: ""

    function findBattery(i) {
        if (i > 2)
            return;
        var base = "/sys/class/power_supply/BAT" + i;
        readFile(base + "/capacity", function (cap) {
            if (cap === "") {
                root.findBattery(i + 1);
            } else {
                root.batteryPath = base;
                root.refreshBattery();
            }
        });
    }

    function refreshBattery() {
        if (batteryPath === "")
            return;
        readFile(batteryPath + "/capacity", function (cap) {
            if (cap === "") {
                batteryLabel.text = "";
                return;
            }
            root.readFile(root.batteryPath + "/status", function (st) {
                var icon = (st === "Charging" || st === "Full")
                         ? "\u{F0084}"                // nf-md-battery_charging
                         : "\u{F0079}";               // nf-md-battery
                batteryLabel.text = icon + "  " + cap + "%";
            });
        });
    }

    // =========================================================================
    // Login
    // =========================================================================
    function doLogin() {
        if (checking || password.text.length === 0)
            return;
        checking = true;
        failed = false;
        // sessionCurrent IS sessionModel.lastIndex while nobody touches the
        // footer selector, so untouched this behaves just as when it said
        // lastIndex outright.
        sddm.login(userName, password.text, sessionCurrent);
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.checking = false;
            root.failed = true;
            root.attempts += 1;
            password.text = "";
            password.forceActiveFocus();
        }

        function onLoginSucceeded() {
            root.checking = false;
            island.opacity = 0;
        }
    }

    // Self-healing focus. Measured: neither Component.onCompleted nor a single
    // deferred retry grabs focus - the window activates later and Qt gives it
    // to nobody, so the field stays mute until you click. This timer insists
    // while the field does NOT have focus and switches itself off as soon as
    // it gets it, so it also recovers it if lost.
    Timer {
        interval: 200
        running: !password.activeFocus
        repeat: true
        triggeredOnStart: true
        onTriggered: password.forceActiveFocus()
    }

    // Last resort: a click anywhere returns focus to the field.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: password.forceActiveFocus()
    }

    Component.onCompleted: {
        password.forceActiveFocus();
        findBattery(0);
        // The live accent. Your user writes the file, not root, so it is
        // validated before use: only exactly #rrggbb is accepted. If missing
        // or failing, theme.conf's stays and nothing shows.
        readFile("/var/lib/sddm-hyprisland/accent", function (txt) {
            if (/^#[0-9a-fA-F]{6}$/.test(txt))
                root.accent = txt;
        });
    }
}
