// LockPam.qml - PAM conversation for the Aroli lock screen.
//
// One shared instance lives in Lock.qml and is used by every LockSurface, but
// only the primary screen drives it (see LockSurface.primary). The flow is the
// stock Quickshell PamContext one:
//
//   begin() -> pam.start() -> responseRequired -> user types -> submit()
//   -> pam.respond(buffer) -> completed(Success|Failed|...).
//
// Fingerprint belongs to the PAM stack itself (pam_fprintd when the machine
// has it): when fprintd reports enrolled fingers we show the affordance, but
// no second auth path is invented in QML. Howdy stays out on purpose.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick

Item {
    id: root

    // Set by LockSurface while the session is locked.
    property bool active: false

    // Password buffer. Cleared the moment it is handed to PAM and whenever
    // the session locks/unlocks, so it never sits in memory longer than a
    // single attempt.
    property string buffer: ""
    property bool checking: false
    property int attempts: 0
    property string errorText: ""
    // Enter pressed before PAM opened the prompt: the keystroke must not
    // die silently (it reads as "Enter is broken, only the button works").
    // Remember it and flush as soon as responseRequired arrives.
    property bool submitPending: false

    // Caps/num state, read from hyprctl (keyboards carry capsLock/numLock).
    property bool capsOn: false
    property bool numOn: false
    property string kbLayout: ""
    // True when fprintd knows fingers for this user.
    property bool fprintEnrolled: false

    readonly property string pamService: "passwd"

    signal authenticated()

    function begin() {
        root.active = true;
        root.buffer = "";
        root.checking = false;
        root.attempts = 0;
        root.errorText = "";
        root.submitPending = false;
        root.refreshKb();
        kbTimer.restart();
        fprintProc.running = false;
        fprintProc.running = true;
        if (!pam.active)
            pam.start();
    }

    function end() {
        root.active = false;
        kbTimer.stop();
        retryTimer.stop();
        if (pam.active)
            pam.abort();
        root.buffer = "";
        root.checking = false;
        root.errorText = "";
        root.submitPending = false;
    }

    function submit() {
        root.refreshKb();
        if (root.checking)
            return;
        // The classic double-Enter: the prompt was already open when the
        // pending flag was set, so no edge ever comes to flush it. Always
        // try the immediate path after (re)starting.
        if (!pam.active)
            pam.start();
        if (root.buffer.length === 0) {
            root.submitPending = false;
            return;
        }
        root.submitPending = true;
        root.flushSubmit();
    }

    function flushSubmit() {
        // NOTE: intentionally NOT gated on root.active: begin() can lose a
        // primary/shown race, and a stuck pending flag reads as "neither
        // button nor Enter unlocks". The pam state below is sufficient.
        // Performs the respond itself; it must NEVER call submit() back
        // (submit->flush->submit is infinite mutual recursion: RangeError,
        // respond never reached, unlock dead from every path).
        if (!root.submitPending || root.checking)
            return;
        if (!pam.active || !pam.responseRequired || root.buffer.length === 0)
            return;
        root.submitPending = false;
        root.checking = true;
        root.errorText = "";
        pam.respond(root.buffer);
        root.buffer = "";
    }

    function statusText() {
        if (root.checking)
            return I18n.tr("Checking…");
        if (root.errorText.length > 0)
            return root.errorText;
        if (root.attempts > 0)
            return I18n.tr("No match · attempt {0}", root.attempts);
        return "";
    }

    function warnText() {
        if (root.capsOn && root.numOn)
            return I18n.tr("Caps lock is ON.") + " " + I18n.tr("Num lock is ON.");
        if (root.capsOn)
            return I18n.tr("Caps lock is ON.");
        if (root.numOn)
            return I18n.tr("Num lock is ON.");
        return "";
    }

    function refreshKb() {
        kbProc.running = false;
        kbProc.running = true;
    }

    PamContext {
        id: pam
        config: root.pamService
        onResponseRequiredChanged: root.flushSubmit()
        onCompleted: function (result) {
            if (result === PamResult.Success) {
                root.checking = false;
                root.authenticated();
            } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
                root.checking = false;
                root.attempts += 1;
                root.errorText = "";
                retryTimer.restart();
            } else {
                root.checking = false;
                root.errorText = pam.messageIsError && pam.message.length > 0 ? pam.message : I18n.tr("Wrong password");
                retryTimer.restart();
            }
        }
        onError: function () {
            root.checking = false;
            root.errorText = pam.message.length > 0 ? pam.message : I18n.tr("Wrong password");
            retryTimer.restart();
        }
    }

    // After a failure the context is spent: open a fresh one before the next
    // attempt so the user can just keep typing.
    Timer {
        id: retryTimer
        interval: 450
        onTriggered: {
            if (root.active && !pam.active)
                pam.start();
        }
    }

    // One line out: "true false Portuguese (Brazil)". Only polled while the
    // session is locked, plus once per submit, so this costs nothing on the
    // desktop.
    Process {
        id: kbProc
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | jq -r '(.keyboards | map(select(.main)) | .[0] // .keyboards[0]) | \"\\(.capsLock) \\(.numLock) \\(.active_keymap)\"'"]
        stdout: SplitParser {
            onRead: function (line) {
                const p = String(line).trim().split(" ");
                if (p.length < 2)
                    return;
                root.capsOn = p[0] === "true";
                root.numOn = p[1] === "true";
                root.kbLayout = p.slice(2).join(" ");
            }
        }
    }
    Timer {
        id: kbTimer
        interval: 2000
        repeat: true
        onTriggered: root.refreshKb()
    }

    Process {
        id: fprintProc
        command: ["sh", "-c", "fprintd-list \"$USER\" 2>/dev/null | head -1"]
        stdout: SplitParser {
            onRead: function (line) {
                if (String(line).trim().length > 0)
                    root.fprintEnrolled = true;
            }
        }
    }
}
