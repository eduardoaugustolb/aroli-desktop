// SettingsSystem.qml — los interruptores del sistema que hasta ahora solo
// existían en el centro de control del notch (Super+D).
//
// POR QUÉ REPETIRLOS AQUÍ: el centro de control es para tocar y salir corriendo
// — está pensado para un gesto. Ajustes es para cuando quieres LEER qué hace
// cada cosa antes de tocarla (para eso está la franja del pie) y para lo que no
// cabe en cuatro botones: el estado de la batería, qué red hay, cuántas
// notificaciones tienes. Ninguno de estos ajustes se guarda en el JSON del
// rice: son estado del sistema y los lee ShellState.
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root

    property string note: I18n.tr("Live system settings: they are not saved in the rice JSON.")
    readonly property int matchCount: cScreen.visibleRows + cPower.visibleRows
        + cNet.visibleRows + cNotif.visibleRows + cTerm.visibleRows

    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    onVisibleChanged: if (visible) contentY = 0

    ColumnLayout {
        id: col
        width: root.width - 48
        x: 24
        y: 16
        spacing: 10

        // ─────────────────── pantalla ───────────────────
        SettingsControls.Card_ {
            id: cScreen
            title: I18n.tr("SCREEN")

            SettingsControls.Row_ {
                shown: ShellState.bright >= 0
                label: I18n.tr("Brightness")
                hint: I18n.tr("The same brightness as the function keys, with the same OSD in the notch.")
                SettingsControls.Slider_ {
                    value: Math.max(0, ShellState.bright); from: 0; to: 100; suffix: " %"
                    onMoved: function (v) { ShellState.setBrightness(v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Night light")
                hint: I18n.tr("Drops the colour temperature to 4000 K with hyprsunset. Super+Shift+N does the same.")
                SettingsControls.Switch_ {
                    checked: ShellState.nightLight
                    onToggled: ShellState.toggleNightLight()
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Reading mode")
                hint: I18n.tr("Turns the screen into warm paper and ink, adds a static e-ink grain and pauses animations, blur and shadows. On leaving it restores exactly what was there before; it does not change the wallpaper, pywal or the brightness.")
                SettingsControls.Switch_ {
                    checked: ShellState.readingMode
                    onToggled: function (v) { ShellState.setReadingMode(v); }
                }
            }
        }

        // ─────────────────── energía ───────────────────
        SettingsControls.Card_ {
            id: cPower
            title: I18n.tr("POWER")

            // En una torre no hay /sys/class/power_supply/BAT*, así que `batt`
            // vale -1 y esta fila decía "sin batería" para siempre. Contar algo
            // que en ese equipo no puede existir no es honestidad, es un hueco
            // con texto: las tres filas de abajo ya se escondían por lo mismo y
            // esta se quedaba sola presidiéndolas. La tarjeta ENERGÍA no se
            // vacía porque Cafeína y el resto siguen ahí.
            SettingsControls.Row_ {
                shown: ShellState.batt >= 0
                label: I18n.tr("Battery")
                hint: I18n.tr("Current charge according to the kernel, the same one the notch shows.")
                SettingsControls.Val_ {
                    text: I18n.tr("{0} % · {1}", ShellState.batt,
                                  ShellState.ac ? I18n.tr("charging") : I18n.tr("on battery"))
                    color: ShellState.batt < 15 && !ShellState.ac ? Colors.crit : "#b9b9b9"
                }
            }

            SettingsControls.Row_ {
                shown: ShellState.batt >= 0 && ShellState.batteryProfileAvailable
                label: I18n.tr("Power profile")
                hint: I18n.tr("Power saver reduces consumption; Balanced adapts to demand; Performance prioritizes speed when your hardware supports it. This changes only Power Profiles Daemon's active profile.")
                SettingsControls.Choice_ {
                    options: {
                        const out = [];
                        if (ShellState.batteryProfiles.indexOf("power-saver") >= 0) out.push(I18n.tr("Power saver"));
                        if (ShellState.batteryProfiles.indexOf("balanced") >= 0) out.push(I18n.tr("Balanced"));
                        if (ShellState.batteryProfiles.indexOf("performance") >= 0) out.push(I18n.tr("Performance"));
                        return out;
                    }
                    current: ShellState.batteryProfileLabel(ShellState.batteryProfile)
                    onPicked: function (v) {
                        if (v === I18n.tr("Power saver")) ShellState.setBatteryProfile("power-saver");
                        else if (v === I18n.tr("Performance")) ShellState.setBatteryProfile("performance");
                        else ShellState.setBatteryProfile("balanced");
                    }
                }
            }

            SettingsControls.Row_ {
                shown: ShellState.battHealth >= 0 || ShellState.battCycles >= 0
                label: I18n.tr("Health")
                hint: I18n.tr("Current maximum capacity against the factory capacity, according to UPower. The cycles come straight from the battery's own counter.")
                SettingsControls.Val_ {
                    text: {
                        const salud = ShellState.battHealth >= 0
                                    ? ShellState.battHealth.toFixed(0) + " %" : I18n.tr("no data");
                        return ShellState.battCycles >= 0
                             ? I18n.tr("{0} · {1} cycles", salud, ShellState.battCycles) : salud;
                    }
                    color: ShellState.battHealth >= 0 && ShellState.battHealth < 60 ? Colors.crit
                        : ShellState.battHealth >= 0 && ShellState.battHealth < 80 ? Colors.warn : "#b9b9b9"
                }
            }

            SettingsControls.Row_ {
                shown: ShellState.battFullWh > 0
                label: I18n.tr("Capacity")
                hint: I18n.tr("Energy it holds when fully charged against the original design. Shown in watt-hours; it is not the charge percentage right now.")
                SettingsControls.Val_ {
                    text: ShellState.battDesignWh > 0
                        ? I18n.tr("{0} of {1}", ShellState.fmtWh(ShellState.battFullWh),
                                  ShellState.fmtWh(ShellState.battDesignWh))
                        : ShellState.fmtWh(ShellState.battFullWh)
                }
            }

            SettingsControls.Row_ {
                shown: ShellState.batt >= 0
                label: I18n.tr("Time left")
                hint: I18n.tr("UPower's estimate from recent consumption. It can take a few minutes to settle after plugging in, unplugging or waking the machine.")
                SettingsControls.Val_ {
                    text: ShellState.battEstimateText
                        + (ShellState.battRateW > 0.05 ? " · " + ShellState.battRateW.toFixed(1) + " W" : "")
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Caffeine")
                hint: I18n.tr("Stops the screen going to sleep and the machine suspending. It turns itself on at start-up; switch it off from the notch when you want to allow sleep.")
                SettingsControls.Switch_ {
                    checked: ShellState.caffeine
                    onToggled: function (v) { ShellState.caffeine = v; }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Remote mode")
                hint: I18n.tr("For connecting over RustDesk from outside: it keeps the session lock but drops the screen blanking and the suspend, which is what used to cut the connection.")
                SettingsControls.Switch_ {
                    checked: ShellState.remoteMode
                    onToggled: ShellState.toggleRemoteMode()
                }
            }
        }

        // ─────────────────── red ───────────────────
        SettingsControls.Card_ {
            id: cNet
            title: I18n.tr("NETWORK")

            SettingsControls.Row_ {
                shown: ShellState.hasWifi
                label: I18n.tr("Wi-Fi")
                hint: I18n.tr("Turns the wifi radio on or off (NetworkManager).")
                SettingsControls.Switch_ {
                    checked: ShellState.wifiOn
                    onToggled: function (v) { ShellState.setWifi(v); }
                }
            }

            SettingsControls.Action_ {
                label: I18n.tr("Available networks")
                hint: I18n.tr("Opens the network picker in the notch. Settings closes so it does not cover it.")
                icon: Icons.wifi
                value: ShellState.wiredDev ? I18n.tr("wired")
                     : ShellState.wifiNet ? ShellState.wifiNet.name
                     : (ShellState.wifiOn || !ShellState.hasWifi) ? I18n.tr("not connected") : I18n.tr("off")
                onTriggered: {
                    ShellState.settingsOpen = false;
                    ShellState.togglePanel("network");
                }
            }

            SettingsControls.Action_ {
                label: I18n.tr("Network profiles")
                hint: I18n.tr("Manages WPA-Enterprise profiles without exposing passwords in commands: identity, EAP method and certificates are stored through NetworkManager.")
                icon: Icons.wifiLock
                value: I18n.tr("EAP and certificates")
                onTriggered: ShellState.openNetworkProfiles()
            }
        }

        // ─────────────────── notificaciones ───────────────────
        SettingsControls.Card_ {
            id: cNotif
            title: I18n.tr("NOTIFICATIONS")

            SettingsControls.Row_ {
                label: I18n.tr("Do not disturb")
                hint: I18n.tr("Notifications still arrive and stay in the Control Centre, but the notch does not announce them.")
                SettingsControls.Switch_ {
                    checked: ShellState.dnd
                    onToggled: function (v) { ShellState.dnd = v; }
                }
            }

            SettingsControls.Action_ {
                label: I18n.tr("Clear all")
                hint: I18n.tr("Discards every saved notification.")
                icon: Icons.bell
                value: ShellState.notifCount === 0 ? I18n.tr("empty")
                     : I18n.tr("{0} unread", ShellState.notifCount)
                onTriggered: ShellState.clearNotifs()
            }
        }

        // ─────────────────── terminal ───────────────────
        SettingsControls.Card_ {
            id: cTerm
            title: I18n.tr("TERMINAL")

            SettingsControls.Row_ {
                label: I18n.tr("Themed Pokémon")
                hint: I18n.tr("The pokémon you get when you open the first terminal is picked from the ones that suit the wallpaper's palette best (blue theme → blue pokémon). Off, you get a random one, as before.")
                SettingsControls.Switch_ {
                    checked: ShellState.pokeTheme
                    onToggled: ShellState.togglePokeTheme()
                }
            }
        }

        SettingsControls.Note_ {
            Layout.topMargin: 10
            visible: ShellState.settingsQuery.length > 0
                     && !cScreen.visible && !cPower.visible && !cNet.visible
                     && !cNotif.visible && !cTerm.visible
            text: I18n.tr("No System setting matches “{0}”.", ShellState.settingsQuery)
        }
    }
}
