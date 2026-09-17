package main

// 2.0 coordination and portability workflows. They deliberately compose the
// existing helpers instead of introducing a resident daemon.

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type sessionMode struct {
	name, description, battery string
	game                       bool
}

var sessionModes = []sessionMode{
	{"laptop", "Economia de energia, sem efeitos de jogo.", "power-saver", false},
	{"desktop", "Equilíbrio para uso diário.", "balanced", false},
	{"gaming", "Desliga efeitos do compositor; mantém energia balanceada.", "balanced", true},
	{"creator", "Equilíbrio para criação e desenvolvimento.", "balanced", false},
}

type modeCoordination struct {
	BatteryBeforeGame string `json:"battery_before_game,omitempty"`
	UpdatedAt         string `json:"updated_at"`
}

func userScript(name string) (string, error) {
	home, err := os.UserHomeDir()
	return filepath.Join(home, ".local", "bin", name), err
}
func modeCoordinationPath() (string, error) {
	home, err := os.UserHomeDir()
	return filepath.Join(home, ".local", "state", "umbra-noctis", "mode-coordination.json"), err
}

func readModeCoordination() (modeCoordination, error) {
	path, err := modeCoordinationPath()
	if err != nil {
		return modeCoordination{}, err
	}
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return modeCoordination{}, nil
	}
	if err != nil {
		return modeCoordination{}, err
	}
	var state modeCoordination
	return state, json.Unmarshal(data, &state)
}
func writeModeCoordination(state modeCoordination) error {
	path, err := modeCoordinationPath()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	state.UpdatedAt = time.Now().Format(time.RFC3339)
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o600)
}
func clearModeCoordination() error {
	path, err := modeCoordinationPath()
	if err != nil {
		return err
	}
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func scriptState(script, action string) (string, error) {
	path, err := userScript(script)
	if err != nil {
		return "", err
	}
	out, err := exec.Command(path, action).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

// prepareGameMode resolves the only meaningful conflict: power-saver can cap
// a game before Feral GameMode has a chance to optimise its process. Reading
// mode and Game Mode both own compositor effects, so reading is turned off
// first. The captured power profile is restored when Game Mode ends.
func prepareGameMode() error {
	if err := reading([]string{"off"}); err != nil {
		return err
	}
	battery, err := scriptState("battery-efficiency", "status")
	if err != nil || battery != "power-saver" {
		return nil
	}
	path, err := userScript("battery-efficiency")
	if err != nil {
		return err
	}
	if out, err := exec.Command(path, "set", "balanced").Output(); err != nil {
		return fmt.Errorf("não foi possível preparar o perfil de energia para jogos: %w", err)
	} else if strings.TrimSpace(string(out)) != "balanced" {
		return errors.New("o perfil de energia não mudou para balanced")
	}
	return writeModeCoordination(modeCoordination{BatteryBeforeGame: battery})
}

func restoreGameModeCoordination() error {
	state, err := readModeCoordination()
	if err != nil || state.BatteryBeforeGame == "" {
		return err
	}
	path, err := userScript("battery-efficiency")
	if err != nil {
		return err
	}
	if _, err := exec.Command(path, "set", state.BatteryBeforeGame).Output(); err != nil {
		return err
	}
	return clearModeCoordination()
}

func reading(args []string) error {
	if len(args) != 1 || (args[0] != "on" && args[0] != "off" && args[0] != "status") {
		return errors.New("use: rice reading on|off|status")
	}
	if args[0] == "on" {
		if state, _ := scriptState("game-mode", "status"); state == "on" {
			if _, err := scriptState("game-mode", "off"); err != nil {
				return err
			}
		}
	}
	pathHome, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	out, err := exec.Command(filepath.Join(pathHome, ".config", "hypr", "scripts", "reading-mode.sh"), args[0]).Output()
	if err != nil {
		return fmt.Errorf("modo leitura indisponível: %w", err)
	}
	fmt.Println(strings.TrimSpace(string(out)))
	return nil
}

func sessionProfile(args []string) error {
	if len(args) == 0 || args[0] == "list" {
		for _, mode := range sessionModes {
			fmt.Printf("  %-8s %s\n", mode.name, mode.description)
		}
		return nil
	}
	if args[0] == "status" && len(args) == 1 {
		game, _ := scriptState("game-mode", "status")
		batteryState, _ := scriptState("battery-efficiency", "status")
		read, _ := readingState()
		fmt.Printf("game: %s\nreading: %s\npower: %s\n", game, read, batteryState)
		return nil
	}
	if len(args) != 2 || args[0] != "apply" {
		return errors.New("use: rice session list|status|apply laptop|desktop|gaming|creator")
	}
	var wanted *sessionMode
	for i := range sessionModes {
		if sessionModes[i].name == args[1] {
			wanted = &sessionModes[i]
		}
	}
	if wanted == nil {
		return fmt.Errorf("perfil de sessão %q não existe", args[1])
	}
	if wanted.game {
		if err := battery([]string{"set", wanted.battery}); err != nil {
			return err
		}
		if err := reading([]string{"off"}); err != nil {
			return err
		}
		return gaming([]string{"on"})
	}
	if err := gaming([]string{"off"}); err != nil {
		return err
	}
	if err := battery([]string{"set", wanted.battery}); err != nil {
		return err
	}
	return reading([]string{"off"})
}

func readingState() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	out, err := exec.Command(filepath.Join(home, ".config", "hypr", "scripts", "reading-mode.sh"), "status").Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func recoverDesktop(args []string) error {
	dry, yes, snapshot := false, false, ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--dry-run":
			dry = true
		case "--yes":
			yes = true
		case "--snapshot":
			if i+1 == len(args) {
				return errors.New("--snapshot precisa de um nome")
			}
			i++
			snapshot = args[i]
		default:
			return errors.New("use: rice recover [--dry-run|--yes] [--snapshot NOME]")
		}
	}
	if snapshot == "latest" {
		root, err := snapshotRoot()
		if err != nil {
			return err
		}
		entries, err := os.ReadDir(root)
		if err != nil {
			return errors.New("não há snapshot local para restaurar")
		}
		var latest string
		var latestTime time.Time
		for _, entry := range entries {
			if !entry.IsDir() {
				continue
			}
			info, err := entry.Info()
			if err == nil && (latest == "" || info.ModTime().After(latestTime)) {
				latest, latestTime = entry.Name(), info.ModTime()
			}
		}
		if latest == "" {
			return errors.New("não há snapshot local para restaurar")
		}
		snapshot = latest
	}
	fmt.Println("Recuperação: desligaria Game Mode e Modo leitura, recarregaria Hyprland e reiniciaria Quickshell.")
	if snapshot != "" {
		fmt.Printf("Também restauraria o snapshot %q.\n", snapshot)
	}
	if dry {
		return nil
	}
	if !yes && !confirm(bufio.NewReader(os.Stdin), "Aplicar esta recuperação?") {
		return nil
	}
	_, _ = scriptState("game-mode", "off")
	_ = reading([]string{"off"})
	_ = clearModeCoordination()
	if snapshot != "" {
		if err := snapshots([]string{"restore", snapshot, "--yes"}); err != nil {
			return err
		}
	}
	if _, err := exec.LookPath("hyprctl"); err == nil {
		_ = exec.Command("hyprctl", "reload").Run()
	}
	if _, err := exec.LookPath("systemctl"); err == nil {
		_ = exec.Command("systemctl", "--user", "restart", "quickshell.service").Run()
	}
	fmt.Println("Recuperação concluída. Execute rice diagnose para um relatório completo.")
	return nil
}

type portablePreferences struct {
	Version         int      `json:"version"`
	ExportedAt      string   `json:"exported_at"`
	Language        string   `json:"language,omitempty"`
	Wallpaper       string   `json:"wallpaper,omitempty"`
	Session         string   `json:"session,omitempty"`
	OptionalPlugins []string `json:"optional_plugins,omitempty"`
}

func exportPreferences(args []string) error {
	if len(args) != 1 {
		return errors.New("use: rice export DIRETÓRIO")
	}
	dest, err := filepath.Abs(args[0])
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dest, 0o755); err != nil {
		return err
	}
	if _, err := os.Stat(filepath.Join(dest, "umbra-preferences.json")); err == nil {
		return errors.New("o diretório já contém um export do Umbra; escolha outro destino")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	for _, rel := range []string{".config/quickshell-rice.json", ".config/hypr/language.conf"} {
		source := filepath.Join(home, rel)
		if _, err := os.Lstat(source); err == nil {
			if err := copyTree(source, filepath.Join(dest, rel)); err != nil {
				return err
			}
		}
	}
	pref := portablePreferences{Version: 1, ExportedAt: time.Now().Format(time.RFC3339)}
	if data, err := os.ReadFile(filepath.Join(home, ".config", "hypr", "language.conf")); err == nil {
		pref.Language = strings.TrimSpace(string(data))
	}
	if target, err := os.Readlink(filepath.Join(home, ".cache", "wal", "lockbg")); err == nil {
		pref.Wallpaper = filepath.Base(target)
	}
	for _, p := range riceProfiles {
		for _, name := range p.plugins {
			if _, err := exec.Command("pacman", "-Q", name).Output(); err == nil {
				pref.OptionalPlugins = append(pref.OptionalPlugins, name)
			}
		}
	}
	data, err := json.MarshalIndent(pref, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(dest, "umbra-preferences.json"), data, 0o600); err != nil {
		return err
	}
	fmt.Printf("Preferências exportadas para %s\n", dest)
	return nil
}

func importPreferences(args []string) error {
	if len(args) < 1 || len(args) > 2 || (len(args) == 2 && args[1] != "--yes") {
		return errors.New("use: rice import DIRETÓRIO [--yes]")
	}
	source, err := filepath.Abs(args[0])
	if err != nil {
		return err
	}
	data, err := os.ReadFile(filepath.Join(source, "umbra-preferences.json"))
	if err != nil {
		return err
	}
	var pref portablePreferences
	if err := json.Unmarshal(data, &pref); err != nil || pref.Version != 1 {
		return errors.New("arquivo de preferências inválido ou incompatível")
	}
	if len(args) == 1 && !confirm(bufio.NewReader(os.Stdin), "Importar preferências visuais deste diretório?") {
		return nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	for _, rel := range []string{".config/quickshell-rice.json", ".config/hypr/language.conf"} {
		from := filepath.Join(source, rel)
		if _, err := os.Lstat(from); err == nil {
			target := filepath.Join(home, rel)
			if _, err := os.Lstat(target); err == nil {
				backup := target + ".before-import-" + time.Now().Format("20060102-150405")
				if err := os.Rename(target, backup); err != nil {
					return err
				}
			}
			if err := copyTree(from, target); err != nil {
				return err
			}
		}
	}
	if pref.Wallpaper != "" {
		wall := filepath.Join(home, "Pictures", "wallpapers", filepath.Base(pref.Wallpaper))
		if _, err := os.Stat(wall); err == nil {
			_ = setWallpaper(wall)
		}
	}
	if len(pref.OptionalPlugins) > 0 {
		fmt.Printf("Opcionais exportados (não instalados automaticamente): %s\n", strings.Join(pref.OptionalPlugins, ", "))
	}
	fmt.Println("Preferências importadas. As versões anteriores receberam o sufixo .before-import-…")
	return nil
}
