-- ###########################################################################
--  HYPRLAND CONFIG IN LUA  (Hyprland 0.56+)
--
--  Translated from hyprland.conf on 2026-08-05. The original .conf stays
--  alongside as fallback: if you delete or rename THIS file, Hyprland goes
--  back to reading it alone ("Lua config not found, using legacy config at ...").
--  The two do not coexist: if hyprland.lua exists, hyprland.lua wins.
--
--  WHY THE SWITCH: springs. A bezier does not know where it is, only
--  how much is left, so changing destination mid-flight forces it to
--  cut and start over -- that rubber-band feel chaining two
--  Super+Arrow presses. A spring has state (position and velocity) and
--  carries on from where it was. In Hyprland that ONLY exists via the Lua config.
--  See ~/.config/motion-language.md, "Springs" section.
--
--  If loading fails, Hyprland enters emergency mode and keeps
--  SUPER+Q alive to open a terminal. You are never locked out.
-- ###########################################################################


------------------
---- MONITORS ----
------------------

-- The WILDCARD rule (output = "") fits any output, so plugging in
-- a second monitor needs no changes: 'preferred' picks the native mode and
-- 'auto' lays it right of the previous one, in discovery order. This
-- is on purpose and is NOT replaced with hardcoded names: 'eDP-1' on the laptop
-- and 'DP-4'/'DP-6' on the tower are the same config, and a list of concrete
-- names would only work on the machine where it was written.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- If some machine needs fine-tuning (two different-size screens you want
-- bottom-aligned, a 4K that reads tiny at scale 1, or the left/right order
-- flipped), the way is adding NAMED rules BELOW the wildcard: the last one
-- that fits wins, so the one above keeps covering any output you skip.
--
--   hl.monitor({ output = "DP-4", mode = "preferred", position = "0x0",    scale = 1 })
--   hl.monitor({ output = "DP-6", mode = "preferred", position = "2560x0", scale = 1 })
--
-- Names come from `hyprctl monitors`. Position is the top-left corner
-- in ALREADY-SCALED pixels, so if the left one spans 2560 wide at scale 1,
-- the next starts at 2560.


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "nautilus"


-------------------
---- AUTOSTART ----
-------------------

-- UWSM exports the session environment to D-Bus and systemd.
-- Quickshell (bar + notch) is supervised by quickshell.service: if it crashes,
-- systemd raises it. Hypridle and the PolicyKit agent stay supervised by
-- their user services. Waybar is replaced by Quickshell's MenuBar.qml + Notch.qml.
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/awww-start.sh")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")   -- clipboard (text)
    hl.exec_cmd("wl-paste --type image --watch cliphist store")  -- clipboard (images)
    -- Shake to find (like macOS): shaking the mouse enlarges the cursor. The
    -- script loads the dynamic-cursors plugin pinned to this Hyprland version
    -- and leaves it with ONLY the shake (mode none); if Hyprland updated and
    -- the .so no longer matches, it rebuilds itself and notifies.
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/dynamic-cursors.sh")
    -- The rice bar (notch/dynamic island) instead of Omarchy's.
    -- quickshell.service carries ConditionEnvironment=WAYLAND_DISPLAY and when
    -- graphical-session.target activates the environment is not imported yet,
    -- so the condition fails and the unit never starts: it is raised here, once
    -- WAYLAND_DISPLAY exists. Omarchy's shell leaves the same way from the
    -- default autostart (it always loads and self-supervises), so it is
    -- stopped: the supervisor first, so it does not relaunch it.
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR && systemctl --user start quickshell")
    -- [l]/[p] in brackets: the pattern never matches its own
    -- `sh -c` line running it (pkill -f looks at the full line and would kill itself).
    hl.exec_cmd("pkill -f 'omarchy-launch-shel[l]'; pkill -f 'quickshell -n -[p]'")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME", "Umbra")
hl.env("XCURSOR_SIZE",  "32")


-----------------------------
---- PYWAL COLORS ----
-----------------------------

-- pywal writes ~/.cache/wal/colors-hyprland.lua from the template
-- ~/.config/wal/templates/colors-hyprland.lua (twin of the eternal .conf,
-- still generated in case you go back to the legacy config).
-- pcall: if the file does not exist yet -- first boot, cleared cache --
-- the config does NOT blow up, it keeps these fallback colors.
local wal = {
    active_border   = { "rgb(394aad)", "rgb(a15bc8)" },
    active_angle    = 45,
    inactive_border = "rgb(648a91)",
    shadow_color    = "rgba(000000ee)",
    background      = "rgb(000000)",
}
do
    local ok, loaded = pcall(dofile, os.getenv("HOME") .. "/.cache/wal/colors-hyprland.lua")
    if ok and type(loaded) == "table" then
        for k, v in pairs(loaded) do wal[k] = v end
    end
end


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        -- Law 8 -- a single gap across the content layer. 3/6 default: between
        -- two windows 6 px (3 + 3) and to the screen edge 6 more — THE SAME
        -- gap. Settings > Appearance > Windows flips it live (effects.lua,
        -- which wins over this block by loading last).
        gaps_in  = 3,
        gaps_out = 6,

        -- Law 2 -- no border by default, on purpose: focus is marked with light,
        -- not outline. Settings > Appearance > Windows flips it live
        -- (effects.lua) and the border already comes themed from pywal (above).
        -- 0 = light/shadow only; 2 = themed outline.
        border_size = 0,

        col = {
            active_border   = { colors = wal.active_border, angle = wal.active_angle },
            inactive_border = wal.inactive_border,
        },

        resize_on_border = true,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        -- Rounded window corners. 12 default; Settings > Appearance >
        -- Windows flips it live (effects.lua, which wins over this block by
        -- loading last) and survives reload/restart. 0 = square.
        -- motion-blur NOTE: with rounding > 0 both shaders exclude each other
        -- inside Hyprland (USE_ROUNDING && !USE_MOTION_BLUR), so corners come
        -- out straight just while the window travels. Compositor limit, not a bug.
        rounding       = 12,
        rounding_power = 2.0,

        -- Law 2 -- focus is marked with light. The focused one is FULLY
        -- present; the rest sink. dim_inactive darkens instead of fading,
        -- which is the clean way for something to recede: fading lets the
        -- background seep between letters.
        active_opacity   = 1.0,
        inactive_opacity = 0.90,
        dim_inactive     = true,
        dim_strength     = 0.35,
        dim_special      = 0.5,

        -- The shadow says "this floats". Tiled windows sit glued to the
        -- grid and carry none (window_rule below); floating ones and
        -- dialogs do. Information about the plane, not decoration.
        shadow = {
            enabled      = true,
            range        = 28,
            render_power = 4,
            color        = wal.shadow_color,
        },

        -- At size 3 / passes 1 the blur never showed. NOTE: not only
        -- kitty pays for this (0.95 opacity). With inactive_opacity = 0.90,
        -- EVERY unfocused window has alpha < 1 and Hyprland runs the full blur
        -- chain on it; in a 2+ window mosaic half the screen is always
        -- blurring. The expensive case: workspace slide + motion blur + this
        -- blur, all at once.
        -- IF YOU NOTICE STUTTER: go back to size = 3 / passes = 1.
        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            noise             = 0.01,
            vibrancy          = 0.1696,
            vibrancy_darkness = 0.2,
            popups            = true,
        },

        -- Law 5 -- what CROSSES the screen leaves a trail. Hyprland 0.56
        -- blurs the window along its travel direction, and only
        -- while the animation lasts. Same idea as the curves below,
        -- but applied to pixels instead of time.
        --
        -- With rounding > 0 (default 12) both shaders exclude each other inside
        -- Hyprland (USE_ROUNDING && !USE_MOTION_BLUR): corners come out straight
        -- just while the window travels, and return to radius on landing.
        --
        -- Mouse dragging pays nothing either: animate_mouse_windowdragging
        -- is already false, and with no animation there is no trail to compute.
        -- Cost lives only in transitions, where it shows.
        --
        -- 'samples' is the copies averaged along the path: more
        -- samples, smoother trail and pricier. It does NOT lengthen the trail;
        -- how far the window moved decides that.
        --
        -- THESE ARE THE BOOT VALUES. The Settings > Appearance > Effects
        -- switch rules; see the end of the file.
        motion_blur = {
            enabled = true,
            samples = 7,
        },
    },

    animations = { enabled = true },
})


-- ==========================================================================
--  MOTION. The full spec lives in ~/.config/motion-language.md
--  Speed runs in DECISECONDS: 1.3 = 130 ms. Literally the same
--  four numbers as the ~/.config/quickshell/Appearance.qml tokens, so
--  a window and the notch move on the same pulse.
--
--     RESPONSE  1.3 / 1.3    focus, zoom, border color
--     CONTENT   2.1 / 1.1    fades
--     PANEL     3.2 / 1.7    layers
--     SHAPE     4.4 / 2.2    opening and closing a window, and MOVING it
--     TRAVEL    5.0          what CROSSES the whole screen
--
--  If something moves here and is not on that scale, it is a bug.
-- ==========================================================================

-- Three curves, and no more. The system's fourth ('entra', the bouncy one)
-- lives ONLY in Quickshell and on scales: by law 5 what TRANSLATES never
-- bounces, because overshooting shows the screen edge.
hl.curve("respuesta", { type = "bezier", points = { {0.2,  0},    {0,    1} } })
hl.curve("sale",      { type = "bezier", points = { {0.3,  0},    {1,    1} } })
hl.curve("forma",     { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("entra",     { type = "bezier", points = { {0.16, 1.3},  {0.3,  1} } })

-- 'apple': the iOS/macOS transition curve. Starts with a touch of
-- acceleration instead of shooting off -- that is what makes it feel like
-- something with mass getting going -- then brakes for nearly the whole
-- travel.
hl.curve("apple",     { type = "bezier", points = { {0.32, 0.72}, {0,    1} } })

-- ---------------------------------------------------------------------------
--  THE SPRING. What a bezier cannot do.
--
--  Moving a window with Super+arrows is the only desktop thing you chain
--  at times: two or three in a row to place it. With a bezier each
--  press CUTS the previous one and restarts from wherever it was, and that
--  reads as rubber. The spring keeps the velocity it carried and chains.
--
--  The three numbers, in physics not taste:
--    w0 = sqrt(stiffness/mass) = sqrt(130) = 11.4 rad/s  -> natural frequency
--    zeta = dampening / (2*sqrt(stiffness*mass)) = 23 / 22.8 = 1.01
--
--  zeta = 1.01 is critically damped: arrives as fast as possible
--  WITHOUT overshooting. That is not shyness, it is law 5 -- overshooting would
--  land the window a hair over the neighbor it just swapped with, and
--  that is not character, it is a placement bug.
--
--  TO MAKE IT DRIER: raise stiffness and raise dampening with it, keeping
--  dampening ~= 2*sqrt(stiffness). Pairs that work:
--      180 / 26.8  -> ~440 ms, right on SHAPE
--      250 / 31.6  -> ~370 ms, more nervous
--  Dropping dampening below 2*sqrt(stiffness) starts bouncing, and there
--  you leave law 5 on purpose. Try it if you like, but knowing you do.
-- ---------------------------------------------------------------------------
hl.curve("mover", { type = "spring", stiffness = 130, dampening = 23, mass = 1 })

hl.animation({ leaf = "global", enabled = true, speed = 3.2, bezier = "forma" })

-- Law 6 -- motion has an origin. A tiled window INFLATES in its
-- slot; it never flies in from an edge. The tiling already decided the place,
-- and flying in disproves it.
hl.animation({ leaf = "windows",   enabled = true, speed = 4.4, bezier = "entra", style = "popin 78%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.4, bezier = "entra", style = "popin 78%" })

-- Opening spans 22 scale points (78->100) and closing only 10 (100->90).
-- Deliberately asymmetric, not sloppy: opening is an event and
-- deserves gesture; closing is a discard and only has to get out of the way.
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, bezier = "sale", style = "popin 90%" })

-- THE CHANGE LIVES HERE. Before: speed 3.2 with bezier 'forma'.
-- Two things at once: (1) the spring, for chaining presses; and (2)
-- it sat on the PANEL step (3.2) when the table says moving a whole window
-- is SHAPE. Law 4 ("frequency drops weight one step") seemed to
-- justify it, but that same law's nuance is that "cannot weigh"
-- means START NOW, not last little -- and starting now is the spring's
-- job, leaving with the full force of the compressed coil.
-- With spring, 'speed' is the ceiling duration; physics rules.
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.4, spring = "mover" })

hl.animation({ leaf = "fade",       enabled = true, speed = 2.1, bezier = "forma" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2.1, bezier = "forma" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 1.1, bezier = "sale" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 2.1, bezier = "forma" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 2.1, bezier = "forma" })

-- Focus. With follow_mouse = 1 it shifts constantly, so dimming
-- must be RESPONSE: if it lagged, the whole desktop would shiver every time
-- you cross the mouse over a window.
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1.3, bezier = "respuesta" })

-- Layers (the bar and notch panels, launcher, notifications): they FADE.
-- Nothing fullscreen slides in; it would show the edge it enters by.
hl.animation({ leaf = "layers",        enabled = true, speed = 3.2, bezier = "forma", style = "fade" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3.2, bezier = "forma", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.7, bezier = "sale", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3.2, bezier = "forma" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.7, bezier = "sale" })

-- THE WORKSPACE SWITCH, MACOS STYLE. All the way: 'slide', not 'slidefade'.
-- Both workspaces sit glued like two adjoining rooms and the
-- screen travels 100% from one side to the other, together, with no fade at
-- all. Fade is exactly what gives away two superimposed images; without it,
-- they are a place you leave and one you arrive at. (Law 10: the problem was
-- never duration or curve, 'slidefade 20%' was SHORTENING the travel.)
-- No bounce: it is a translation, and overshooting would leave a background
-- strip peeking on the far side right at the end.
hl.animation({ leaf = "workspaces",          enabled = true, speed = 5.0, bezier = "apple", style = "slide" })
hl.animation({ leaf = "workspacesIn",        enabled = true, speed = 5.0, bezier = "apple", style = "slide" })
hl.animation({ leaf = "workspacesOut",       enabled = true, speed = 5.0, bezier = "apple", style = "slide" })
hl.animation({ leaf = "specialWorkspace",    enabled = true, speed = 5.0, bezier = "apple", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 5.0, bezier = "apple", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 5.0, bezier = "apple", style = "slidevert" })

-- Invisible (border_size = 0), but the node exists: so it never sits at
-- factory speed sounding off-key the day you switch borders on.
hl.animation({ leaf = "border", enabled = true, speed = 1.3, bezier = "respuesta" })

-- borderangle / shadowangle / glowangle on 'loop' force continuous repaint at
-- 60 Hz even unseen. On an Iris Xe that is decoration paid in
-- frames. They stay off (law 7: nothing moves just because).
hl.animation({ leaf = "borderangle", enabled = false, speed = 1, bezier = "default" })
hl.animation({ leaf = "shadowangle", enabled = false, speed = 1, bezier = "default" })
hl.animation({ leaf = "glowangle",   enabled = false, speed = 1, bezier = "default" })

hl.animation({ leaf = "zoomFactor", enabled = true, speed = 1.3, bezier = "respuesta" })


--------------------------
---- WORKSPACES ----
--------------------------

-- Always three workspaces. Hyprland destroys a workspace as soon as it sits
-- empty, so the indicator row resized itself: closing the last window on 3
-- and the dot vanished. 'persistent' keeps them existing even empty.
--
-- Done HERE and not by painting extra dots in the shell on purpose: this way
-- the three workspaces truly exist, so the dot is clickable and takes you
-- there. A painted dot matching nothing would be a lying decoration.
--
-- They are a MINIMUM, not a cap: creating 4 shows its dot alone, and it leaves
-- when emptied. The first three always stay.
-- WITH TWO SCREENS this is shared and worth knowing: workspaces do NOT
-- duplicate per monitor, numbering is session-wide. Hyprland hands each output
-- one at boot (the first gets 1, the second 2) and places leftover persistents
-- where it can, so Super+2 from the left screen does not change what you see
-- there: it moves FOCUS to the screen where 2 lives. Stock Hyprland behavior,
-- not a bug.
--
-- The bar no longer lies about this: each screen paints ONLY its workspaces and
-- marks its own active one (see TopShell.qml, the ws.monitor filter).
--
-- If the tower should split them by hand —say 1 and 2 on the primary
-- and 3 on the secondary— the monitor joins the rule, with whatever names
-- `hyprctl monitors` reports:
--
--   hl.workspace_rule({ workspace = "1", persistent = true, monitor = "DP-4" })
--   hl.workspace_rule({ workspace = "2", persistent = true, monitor = "DP-4" })
--   hl.workspace_rule({ workspace = "3", persistent = true, monitor = "DP-6" })
--
-- Not done here because the names belong to one machine and this file
-- is shared by laptop and tower.
for i = 1, 3 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end


---- LAYOUTS ----

hl.config({
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
})

-- Cursor: hyprcursor OFF on purpose. Umbra is an XCursor theme, not a
-- hyprcursor theme.
-- SVG theme (when available, for shake-to-find
-- sharpness) made Hyprland also use it for the NORMAL cursor and Eduardo
-- Augusto noticed it differs from the usual XCursor bitmap. With this the normal
-- cursor is the lifelong one; the shake enlargement scales that bitmap with
-- smooth filtering (hyprcursor:nearest 0, below). Plugin and compositor share
-- switch and theme, so SVG-in-zoom + bitmap-normal cannot coexist: flipping
-- this back to true changes the cursor.
hl.config({
    cursor = { enable_hyprcursor = false },
})

-- Shake to find (dynamic-cursors plugin): the SOURCE OF TRUTH for its config
-- is THIS block, not the script. It must live here because every reload
-- resets plugin options to defaults (and the default is mode=tilt, the
-- cursor leaning as it moves) -- and the wallpaper chain does reloads. The
-- pcall is for BOOT: the .lua parses before dynamic-cursors.sh loads the
-- plugin and these keys do not exist yet; the script reloads after loading it
-- and then this truly applies.
-- NOTE syntax: dynamic_cursors with underscore (maps to
-- plugin:dynamic-cursors:*); with a hyphen it errors "unknown config key".
-- Deliberate profile: threshold 7 ignores ordinary mouse movement; a modest
-- 1.35× start and 2.4× ceiling keep it useful without dominating the screen.
-- A short tail avoids an abrupt snap back on release.
pcall(function()
    hl.config({
        plugin = {
            dynamic_cursors = {
                mode = "none",
                shake = { threshold = 5.0, base = 1.5, speed = 1.1, influence = 0.8, limit = 2.4, timeout = 700 },
                -- High-resolution source extracted directly from the installed
                -- Umbra XCursor theme. It retains its original bitmaps,
                -- hotspots, and per-size variants, so zoom matches rest.
                hyprcursor = { enabled = true, nearest = 0, resolution = 256 },
            },
        },
    })
end)


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        background_color        = wal.background,

        -- From caelestia: STATE CHANGES animate, not live interaction.
        -- Dragging or mouse-resizing already tracks your hand 1:1, so
        -- animating it adds nothing and on an iGPU is continuous repaint tied
        -- to the pointer (the priciest path there is). Not a shred of feel is
        -- lost and GPU frees up exactly when most needed.
        animate_manual_resizes       = false,
        animate_mouse_windowdragging = false,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        -- ABNT2 keyboard (br). The repo defaults to "es"; on this machine
        -- br is used (empty variant = abnt2). See also `localectl` for
        -- console/X11: `sudo localectl set-keymap br` and
        -- `sudo localectl set-x11-keymap br pc105 "" terminate:ctrl_alt_bksp`.
        kb_layout    = "br",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad     = { natural_scroll = true },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Three fingers down: pulls the month calendar down from the notch.
-- Same hand posture as the gesture above, other axis. `finish` not
-- `update`: this is no continuous drag like the workspace one, it is an
-- order run once, when you lift your fingers.
--
-- It never opens by clicking the clock, the first thing tried: that click has
-- always opened the control center and taking a learned gesture away in
-- exchange for a new feature is a bad deal. The calendar also has its tile
-- in the control center, the door you can see.
hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = {
        finish = function() hl.dsp.global("quickshell:calendar") end,
    },
})


---------------------
---- SHORTCUTS ----
---------------------

local mainMod = "SUPER"

-- Screenshots
-- Region: freezes the screen before picking the crop, so it also
-- photographs what closes on losing focus (the Super+D notch, a menu,
-- a dropdown). See ~/.config/hypr/scripts/capture-region.sh.
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-region.sh"))
-- FULL instant capture (grim steals no focus -> it does capture menus like rofi).
-- Super+Shift+P is the RELIABLE key; Print works if your keyboard emits that keysym.
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-full.sh"))
hl.bind("Print",                   hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-full.sh"))

hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"))
-- Clipboard history. No longer calls the cliphist rofi: opens the notch
-- launcher straight into its "#" mode. Data still comes from cliphist
-- (wl-paste --watch stores it up top, in exec-once); only who paints and
-- who searches changes.
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.global("quickshell:clipboard"))

-- Basics
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("uwsm app -- " .. terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("uwsm app -- " .. fileManager))


-- Local AI: panel that knows this system. Special workspace so the
-- session and model stay alive between presses.
--
-- ~/ia-local is a self-contained module: ALL of it lives in there, including
-- this panel. The bind registers ONLY if the module exists, so deleting the
-- directory never leaves a dead Super+I that looks alive and does nothing.
-- The inventory of what the module touches outside is in ~/ia-local/HUELLA.md.
local ia_panel = os.getenv("HOME") .. "/ia-local/bin/ia-panel"
local ia_f = io.open(ia_panel, "r")
if ia_f then
    ia_f:close()
    hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(ia_panel))
end
-- First press: floating at 60% and centered. Second: back to tiling.
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-float-centered.sh"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("~/.config/quickshell/reload.sh"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("kitty --class pokemon-popup -e ~/.config/hypr/scripts/pokemon-popup.sh"))

-- Quickshell (bar + notch). 'global' reaches the shell over IPC.
hl.bind(mainMod .. " + R",         hl.dsp.global("quickshell:launcher"))   -- launcher from the notch
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.global("quickshell:media"))      -- floating player
hl.bind(mainMod .. " + N",         hl.dsp.global("quickshell:notchstyle")) -- toggles notch <-> island
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.global("quickshell:wallpaper"))  -- wallpaper picker
hl.bind(mainMod .. " + TAB",       hl.dsp.global("quickshell:overview"))   -- window overview
hl.bind(mainMod .. " + D",         hl.dsp.global("quickshell:notch"))      -- control center
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.global("quickshell:system"))     -- machine status
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.global("quickshell:power"))      -- power menu
hl.bind(mainMod .. " + comma",     hl.dsp.global("quickshell:settings"))   -- Settings (like Cmd+, on macOS)
hl.bind(mainMod .. " + A",         hl.dsp.global("quickshell:settings"))   -- Super+, alias
-- Super+K opened ~/.config/hypr/list_keybinds.sh: a rofi parsing THIS
-- same file (well, its .conf mirror) to show the shortcut list. But
-- Settings > Shortcuts already did exactly that parsing, so they were two
-- lists matching only while nobody touched either. The key is the same as
-- ever; what opens now is the list that already lived in the notch.
hl.bind(mainMod .. " + K",         hl.dsp.global("quickshell:keybinds"))   -- shortcut map (Settings > Shortcuts)

hl.bind(mainMod .. " + W",         hl.dsp.global("quickshell:bar"))        -- hide/show the bar

-- Move FOCUS with Super + Shift + arrows
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.focus({ direction = "d" }))

-- Move/swap the WINDOW with Super + arrows. This is what fires
-- 'windowsMove', the spring above.
hl.bind(mainMod .. " + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.window.move({ direction = "d" }))

-- Workspaces with Super + [0-9], and sending the window there with Super+Shift.
for i = 1, 10 do
    local key = i % 10  -- 10 goes on the 0 key
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Mouse wheel switches workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize dragging with Super + button
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume/brightness: the notch paints the OSD (Quickshell). Volume is detected
-- Pipewire-only; the notch itself flips brightness over IPC so there is no
-- lag or value skew.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 2%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("qs ipc call notch bright up"),                      { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call notch bright down"),                    { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Physical power button
hl.bind("XF86PowerOff", hl.dsp.global("quickshell:power"))

-- Quick wins
hl.bind(mainMod .. " + CTRL + S",  hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-annotate.sh")) -- annotate capture (satty)
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/colorpicker.sh"))         -- eyedropper (hyprpicker)
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/hyprsunset-toggle.sh"))   -- night light

-- Signature: menu / ocr
-- The command menu is no longer a rofi either: it is the launcher's ">" mode.
-- Same key, same list (plus what that menu could never offer from outside
-- the shell: settings, workspace map, do-not-disturb, caffeine).
--
-- A third bind used to live here, Super+Ctrl+W, installing a web page as an
-- "app". Retired 19-08-2026: the LAST thing still launching rofi, and neither
-- ~/.local/share/webapps nor a single web-app .desktop ever existed all this
-- time. The script sits in ~/.config/webapp-install-retirado-*.tar.gz.
hl.bind(mainMod .. " + ALT + Space", hl.dsp.global("quickshell:actions"))                       -- command menu
hl.bind(mainMod .. " + CTRL + T",    hl.dsp.exec_cmd("~/.config/hypr/scripts/ocr.sh"))          -- screen OCR

-- Screen recording (wf-recorder)
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh"))


--------------------------------
---- WINDOWS AND LAYERS ----
--------------------------------

-- --- Quickshell Settings app (SettingsWindow.qml) ---
-- The only true window (xdg-toplevel) in the shell: class org.quickshell,
-- title "Ajustes"; the rest of the shell is layers (layer-shell) and never
-- passes through here. Without these rules it opened TILED at half screen
-- (952x1038). Size also lives in the QML (implicitWidth/Height) so no big
-- flash precedes Hyprland resizing it. Never below 780 wide: the window has
-- its own minimum there.
hl.window_rule({
    name  = "ajustes-quickshell",
    match = {
        class = "^(org\\.quickshell)$",
        title = "^(Ajustes)$",
    },
    float  = true,
    size   = { 900, 620 },
    center = true,
})

-- The shadow says "this is what you are looking at": ONLY the focused window
-- casts it. Together with dim_inactive, focus stops being a nuance and becomes
-- the first thing the eye sees entering the screen, without a single border
-- line. (This used to be "floaters only", which in a tiling is almost never:
-- the rule was right on paper and in practice never showed.)
hl.window_rule({
    name      = "sombra-solo-en-foco",
    match     = { focus = 0 },
    no_shadow = true,
})

-- --- Law 9: one animation, one owner ---
-- The compositor animates surfaces that APPEAR; the app animates the inside.
--
-- Quickshell's bar/notch is a PERMANENT layer that resizes itself
-- and already animates itself (Appearance.qml tokens). If Hyprland animated it
-- too, two animations would chain over the same gesture and smear. Command
-- is yielded to Quickshell here.
hl.layer_rule({
    name    = "sin-anim-barra",
    match   = { namespace = "^(quickshell:bar)$" },
    no_anim = true,
})

-- Law 6 applied to shell surfaces: each enters from where it should,
-- instead of one generic fade for all. The rule comes from law 9: look at
-- WHAT the app already animates inside and give the compositor only what is
-- left free. If both animate the same thing, both fades multiply and the
-- result is not twice as pretty, it arrives late.
--
-- media: lives glued to the bottom edge, so it RISES from there. 'slide' moves
-- position and nothing else -- no fade -- and the card inside already handles
-- scale and opacity. Separate channels, no stepping on each other.
hl.layer_rule({
    name      = "media-sube",
    match     = { namespace = "^(quickshell:media)$" },
    animation = "slide bottom",
})

-- wallpaper: covers the whole screen, so sliding it would show the edge
-- it enters by. And besides, its 'stage' already fades alone (animMed,
-- OutCubic). The compositor has nothing to add here: stand aside.
hl.layer_rule({
    name    = "sin-anim-wallpaper",
    match   = { namespace = "^(quickshell:wallpaper)$" },
    no_anim = true,
})

-- overview: the reverse of the other two. Thumbnails cascade in alone,
-- but nobody inside animates the black veil (PanelWindow color, 55%).
-- With no_anim the cascade would appear over black already slammed on. The
-- compositor fade is exactly what it lacks.
hl.layer_rule({
    name      = "overview-funde",
    match     = { namespace = "^(quickshell:overview)$" },
    animation = "fade",
})

-- A "rofi-blur" rule lived here (blur + ignore_alpha 0.5 over the rofi
-- layer, the only thing with real transparency). It leaves with rofi on
-- 19-08-2026: a rule pointing at a layer nobody creates does nothing except
-- make you believe rofi is still on the desktop.


-- ==========================================================================
--  LO QUE MANDA EL SHELL
--
--  Settings > Appearance > Effects writes effects.lua and also applies it live,
--  so the switch is felt the moment you flip it. This dofile is what makes it
--  SURVIVE on top of that: a `hyprctl reload`, which re-reads this config and
--  would wipe any live change, and a session restart.
--
--  It goes LAST to win over everything above, and guarded with pcall: when the
--  file does not exist -- a freshly installed clone, or a boot without
--  Quickshell -- nothing happens and the values above stand. Same deal
--  hyprlock.conf gives language.conf: defaults first, the layer that may be
--  missing after.
--
--  effects.lua used to be efectos.lua. The old name is still honored when the
--  new file is missing, so updating never drops a live setting; the installer
--  moves it for you on the next run.
-- ==========================================================================
local effects_state = os.getenv("HOME") .. "/.config/hypr/effects.lua"
do
    local probe = io.open(effects_state, "r")
    if probe then
        probe:close()
        pcall(dofile, effects_state)
    else
        pcall(dofile, os.getenv("HOME") .. "/.config/hypr/efectos.lua")
    end
end
