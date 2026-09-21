pragma Singleton
import Quickshell

// Shared design system, like end-4 and caelestia's Appearance/Config.
// Everything (bar, dashboard, OSD, notifications...) uses these tokens => it looks cohesive.
Singleton {
    id: root
    // Mono + Nerd Font: the bar and EVERYTHING that paints icons (glyphs only
    // exist in this family).
    readonly property string font: "JetBrains Mono Nerd Font"

    // Proportional, only for text inside the notch (clock, dates,
    // titles). A date in monospace looks straggly: letters space out
    // like digits and "Tue Aug 4" reads like terminal text.
    readonly property string fontUI: Config.fontUI   // picked in Settings › Appearance

    // font sizes
    readonly property int fsXS: 11
    readonly property int fsS:  12
    readonly property int fsM:  13
    readonly property int fsL:  16
    readonly property int fsXXL: 42

    // radii
    readonly property int radS: 10
    readonly property int radM: 14
    readonly property int radL: 18
    readonly property int radPill: 999

    // spacing
    readonly property int gapS: 6
    readonly property int gapM: 10
    readonly property int gapL: 14
    readonly property int pad:  16

    // ══════════════════════════════════════════════════════════════════════
    //  MOTION, the full scale lives in ~/.config/motion-language.md
    //  Hyprland uses those same four numbers (in deciseconds) for
    //  windows and workspaces. If something moves and is not here, it is a bug.
    //
    //    RESPONSE  130 / 130   hover, press, color, a toggle
    //    CONTENT   210 / 110   text and icons inside something already there
    //    PANEL     320 / 170   a surface appearing
    //    SHAPE     440 / 220   shape change, or something whole moving
    //
    //  Events are asymmetric (leaving takes half the time of entering);
    //  states, like hover, are symmetric.
    // ══════════════════════════════════════════════════════════════════════
    readonly property int mQuick: 130        // RESPONSE: hover, color, press, knobs
    readonly property int mIn: 210           // CONTENT entering (opacity)
    readonly property int mOut: 110          // CONTENT leaving: half
    readonly property int mInScale: 320      // PANEL entering (scale, springy)
    readonly property int mOutScale: 170     // PANEL leaving
    readonly property int mShape: 440        // SHAPE: the notch morph
    readonly property int mOutShape: 220     // SHAPE leaving

    // Aliases from the first batch of tokens. They existed alongside the m*
    // ones with nearly equal numbers (120/220/320), two vocabularies for the
    // same thing was exactly what kept nothing quite fitting. Now they point
    // at the good scale; kept so code still using them does not break.
    readonly property int animFast: mQuick
    readonly property int animMed:  mIn
    readonly property int animSlow: mInScale

    // ─── Curves ───
    // Bounce is banned in TRANSLATIONS: something sliding past its stop shows
    // the screen edge and gives away the trick. But in SCALES there is nothing
    // to show, something inflating a hair past its size just feels alive.
    // That is where the character goes.
    // (Fixed 2026-08-05: law 5 banned both and left the system
    // coherent but bland. See ~/.config/motion-language.md)
    readonly property real mOvershoot: 1.3    // the shape morph
    readonly property real mInOvershoot: 1.05 // entering content and panels
    readonly property real mScaleFrom: 0.90   // where entering things grow from

    // Deliberate exception to the scale: a playback bar is not an
    // accent, it is a continuous signal. If the transition lasts EXACTLY the
    // refresh interval, the bar advances at constant speed and reads
    // as continuous motion instead of hopping every half second. That
    // is why it runs linear and why 500 is not on the scale (law 7).
    readonly property int mTick: 500

    // Stagger is what avoids the smear: the new starts entering just
    // as the old has finished leaving, not at the same time.
    readonly property int mStagger: 110      // = mOut

    // ══════════════════════════════════════════════════════════════════════
    //  SPRINGS, the category difference, not a tweak
    //
    //  A bezier curve has fixed duration: it does not know where it is, only
    //  how much is left. If you change its destination mid-animation it must
    //  CUT and start over, and that is why the system feels rubbery when you
    //  do two things in quick succession.
    //
    //  A spring has STATE: position and velocity. Change the destination mid
    //  flight and it carries on from where it was, at the speed it had. There
    //  is no cut because there is nothing to restart. That is what separates
    //  something that feels physical from something that feels programmed.
    //
    //  The interesting bit: in Hyprland this requires migrating to Lua (0.55+),
    //  but Qt has had it forever and NOBODY in the rice world uses it. Here we do.
    //
    //  Three characters, one per spatial step. 'spring' pulls (more = faster)
    //  and 'damping' brakes (less = more bounce).
    // ══════════════════════════════════════════════════════════════════════
    readonly property real sprTight: 5.2      // RESPONSE: arrives and stays, almost no overshoot
    readonly property real dmpTight: 0.58

    readonly property real sprPanel: 4.0      // PANEL: a surface appearing
    readonly property real dmpPanel: 0.42

    readonly property real sprLoose: 3.1      // SHAPE: the morph, with travel to spare
    readonly property real dmpLoose: 0.34

    // SNAP: high stiffness, for what must LET GO ALL AT ONCE after
    // being held -- the indicator's trailing edge. Pairs
    // with dmpPanel: with lower damping the edge keeps oscillating
    // and the pill throbs after arriving.
    readonly property real sprSquash: 6.5

    // epsilon = when it counts as settled. In pixels, a quarter pixel is
    // invisible and cuts the spring's dead tail; in scale (0..1) a thousand
    // times less is needed or it plants itself 1% off target, which shows at 300 px.
    readonly property real eppPx: 0.25
    readonly property real eppScale: 0.001

    // How far a notch face travels sideways on entry. The notch clips
    // (clip), so content travels INSIDE the slot: you do not see
    // it appear, you see it arrive.
    readonly property int mTravel: 34
}
