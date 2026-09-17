package main

// Daily desktop conveniences deliberately live in the Go CLI instead of the
// installer backend. They are small, explicit operations and never change a
// package selection behind the user's back.

import (
	"bufio"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type riceProfile struct {
	name, description string
	phases            []string
	plugins           []string
}

var riceProfiles = []riceProfile{
	{"minimal", "Base visual do Umbra, sem aplicativos opcionais.", []string{"base", "config", "cursor", "final"}, nil},
	{"desktop", "Desktop completo: pacotes, gráficos, serviços e configuração.", []string{"base", "packages", "cursor", "config", "graphics", "services", "final"}, nil},
	{"creator", "Perfil desktop com ferramentas de criação explicitamente listadas.", []string{"base", "packages", "cursor", "config", "graphics", "services", "final"}, []string{"neovim", "yazi", "onefetch", "visual-studio-code-bin"}},
	{"gaming", "Perfil desktop; drivers e jogos continuam escolhas conscientes.", []string{"base", "packages", "cursor", "config", "graphics", "services", "final"}, nil},
}

func profiles(args []string) error {
	if len(args) == 0 || args[0] == "list" {
		fmt.Println("\nPerfis de instalação")
		for _, p := range riceProfiles {
			fmt.Printf("  %-10s %s\n", p.name, p.description)
		}
		return nil
	}
	if len(args) < 2 || (args[0] != "show" && args[0] != "install") {
		return errors.New("use: rice profile list|show|install NOME")
	}
	p, err := profileByName(args[1])
	if err != nil {
		return err
	}
	fmt.Printf("%s\n  fases: %s\n", p.description, strings.Join(p.phases, ", "))
	if len(p.plugins) > 0 {
		fmt.Printf("  opcionais: %s\n", strings.Join(p.plugins, ", "))
	}
	if args[0] == "show" {
		return nil
	}
	forward := args[2:]
	if len(forward) == 0 {
		forward = []string{}
	}
	// The installer retains ownership of backups, preflight, and confirmations.
	if err := install(append(forward, p.phases...)); err != nil {
		return err
	}
	if len(p.plugins) == 0 {
		return nil
	}
	// A profile names the optional packages, but still gives the user a separate
	// opportunity to decline them unless they deliberately supplied --yes.
	pluginArgs := []string{"install"}
	for _, arg := range forward {
		// Only these flags have a meaning for plugin installation. Installation
		// flags such as --lang and --repo must not leak into its parser.
		if arg == "--dry-run" || arg == "--yes" {
			pluginArgs = append(pluginArgs, arg)
		}
	}
	return plugins(append(pluginArgs, p.plugins...))
}

func profileByName(name string) (riceProfile, error) {
	for _, p := range riceProfiles {
		if p.name == name {
			return p, nil
		}
	}
	return riceProfile{}, fmt.Errorf("perfil %q não existe; veja: rice profile list", name)
}

var snapshotPaths = []string{
	".config/hypr", ".config/quickshell", ".config/kitty", ".config/gtk-3.0", ".config/gtk-4.0", ".config/fastfetch", ".config/yazi",
}

func snapshotRoot() (string, error) {
	h, err := os.UserHomeDir()
	return filepath.Join(h, ".local", "share", "umbra-noctis", "snapshots"), err
}
func validSnapshotName(name string) bool {
	return name != "" && filepath.Base(name) == name && name != "." && name != ".."
}

func snapshots(args []string) error {
	if len(args) == 0 {
		return errors.New("use: rice snapshot create|list|restore NOME")
	}
	root, err := snapshotRoot()
	if err != nil {
		return err
	}
	switch args[0] {
	case "list":
		entries, err := os.ReadDir(root)
		if os.IsNotExist(err) {
			fmt.Println("Nenhum snapshot local.")
			return nil
		}
		if err != nil {
			return err
		}
		for _, e := range entries {
			if e.IsDir() {
				fmt.Println(e.Name())
			}
		}
		return nil
	case "create":
		if len(args) != 2 || !validSnapshotName(args[1]) {
			return errors.New("use: rice snapshot create NOME (somente um nome simples)")
		}
		dest := filepath.Join(root, args[1])
		if _, err := os.Stat(dest); err == nil {
			return fmt.Errorf("o snapshot %q já existe", args[1])
		}
		if err := os.MkdirAll(dest, 0o755); err != nil {
			return err
		}
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		for _, rel := range snapshotPaths {
			src := filepath.Join(home, rel)
			if _, err := os.Lstat(src); err == nil {
				if err := copyTree(src, filepath.Join(dest, rel)); err != nil {
					return err
				}
			}
		}
		return os.WriteFile(filepath.Join(dest, "METADATA"), []byte("created="+time.Now().Format(time.RFC3339)+"\n"), 0o644)
	case "restore":
		if len(args) < 2 || !validSnapshotName(args[1]) {
			return errors.New("use: rice snapshot restore NOME [--yes]")
		}
		assume := len(args) == 3 && args[2] == "--yes"
		src := filepath.Join(root, args[1])
		if _, err := os.Stat(src); err != nil {
			return fmt.Errorf("snapshot %q não existe", args[1])
		}
		if !assume && !confirm(bufio.NewReader(os.Stdin), "Restaurar este snapshot sobre as configurações atuais?") {
			fmt.Println("Nada foi alterado.")
			return nil
		}
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		for _, rel := range snapshotPaths {
			from := filepath.Join(src, rel)
			if _, err := os.Lstat(from); err == nil {
				target := filepath.Join(home, rel)
				backup := target + ".before-snapshot-" + time.Now().Format("20060102-150405")
				if _, err := os.Lstat(target); err == nil {
					if err := os.Rename(target, backup); err != nil {
						return err
					}
				}
				if err := copyTree(from, target); err != nil {
					return err
				}
			}
		}
		fmt.Println("Snapshot restaurado. As versões anteriores foram mantidas com .before-snapshot-…")
		return nil
	default:
		return errors.New("use: rice snapshot create|list|restore NOME")
	}
}

func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		target := dst
		if rel != "." {
			target = filepath.Join(dst, rel)
		}
		info, err := os.Lstat(path)
		if err != nil {
			return err
		}
		if info.IsDir() {
			return os.MkdirAll(target, info.Mode().Perm())
		}
		if info.Mode()&os.ModeSymlink != 0 {
			link, err := os.Readlink(path)
			if err != nil {
				return err
			}
			return os.Symlink(link, target)
		}
		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, info.Mode().Perm())
		if err != nil {
			return err
		}
		_, err = io.Copy(out, in)
		closeErr := out.Close()
		if err != nil {
			return err
		}
		return closeErr
	})
}

func wallpapers(args []string) error {
	if len(args) == 0 {
		return errors.New("use: rice wallpaper list|set|random|import|remove")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	dir := filepath.Join(home, "Pictures", "wallpapers")
	entries, _ := os.ReadDir(dir)
	images := []string{}
	for _, e := range entries {
		if !e.IsDir() {
			ext := strings.ToLower(filepath.Ext(e.Name()))
			if ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp" {
				images = append(images, e.Name())
			}
		}
	}
	sort.Strings(images)
	switch args[0] {
	case "list":
		for _, name := range images {
			fmt.Println(name)
		}
		return nil
	case "set":
		if len(args) != 2 {
			return errors.New("use: rice wallpaper set ARQUIVO")
		}
		return setWallpaper(filepath.Join(dir, filepath.Base(args[1])))
	case "random":
		if len(images) == 0 {
			return errors.New("não há wallpapers instalados")
		}
		var b [1]byte
		if _, err := rand.Read(b[:]); err != nil {
			return err
		}
		return setWallpaper(filepath.Join(dir, images[int(b[0])%len(images)]))
	case "import":
		if len(args) != 2 {
			return errors.New("use: rice wallpaper import /caminho/imagem")
		}
		source, err := filepath.Abs(args[1])
		if err != nil {
			return err
		}
		if _, err := os.Stat(source); err != nil {
			return err
		}
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
		dest := filepath.Join(dir, filepath.Base(source))
		if _, err := os.Stat(dest); err == nil {
			return fmt.Errorf("%s já existe", filepath.Base(source))
		}
		return copyTree(source, dest)
	case "remove":
		if len(args) < 2 {
			return errors.New("use: rice wallpaper remove ARQUIVO [--yes]")
		}
		path := filepath.Join(dir, filepath.Base(args[1]))
		if _, err := os.Stat(path); err != nil {
			return err
		}
		if len(args) < 3 || args[2] != "--yes" {
			if !confirm(bufio.NewReader(os.Stdin), "Mover este wallpaper para a Lixeira?") {
				return nil
			}
		}
		if _, err := exec.LookPath("gio"); err == nil {
			return command("", "gio", "trash", path).Run()
		}
		return os.Rename(path, path+".removed-"+time.Now().Format("20060102-150405"))
	default:
		return errors.New("use: rice wallpaper list|set|random|import|remove")
	}
}

func setWallpaper(path string) error {
	if _, err := os.Stat(path); err != nil {
		return fmt.Errorf("wallpaper não encontrado: %w", err)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	return command("", filepath.Join(home, ".config", "hypr", "set-wallpaper.sh"), path).Run()
}

func doctor(args []string) error {
	fix := len(args) == 1 && args[0] == "--fix"
	if len(args) > 1 || (len(args) == 1 && !fix) {
		return errors.New("use: rice doctor [--fix]")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	script := filepath.Join(home, ".config", "hypr", "set-wallpaper.sh")
	issues := []string{}
	if _, err := os.Stat(script); err != nil {
		issues = append(issues, "script de wallpaper ausente")
	}
	if _, err := exec.LookPath("hyprctl"); err != nil {
		issues = append(issues, "hyprctl não está disponível nesta sessão")
	}
	if _, err := exec.LookPath("quickshell"); err != nil {
		issues = append(issues, "quickshell não está instalado")
	}
	if len(issues) == 0 {
		fmt.Println("Doctor: integrações locais essenciais parecem saudáveis.")
	} else {
		fmt.Println("Doctor encontrou:")
		for _, issue := range issues {
			fmt.Println("  -", issue)
		}
	}
	if !fix {
		fmt.Println("\nPara reaplicar integrações seguras da sessão: rice doctor --fix")
		return nil
	}
	if !confirm(bufio.NewReader(os.Stdin), "Recarregar Hyprland e reiniciar o serviço Quickshell do usuário?") {
		return nil
	}
	if _, err := exec.LookPath("hyprctl"); err == nil {
		_ = command("", "hyprctl", "reload").Run()
	}
	if _, err := exec.LookPath("systemctl"); err == nil {
		_ = command("", "systemctl", "--user", "restart", "quickshell.service").Run()
	}
	fmt.Println("Doctor aplicou as reparações de sessão disponíveis.")
	return nil
}

func status() error {
	fmt.Printf("Umbra Noctis CLI %s\n", cliVersion())
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	checks := []struct {
		label, command string
		args           []string
	}{{"Hyprland", "hyprctl", []string{"version"}}, {"Quickshell", "systemctl", []string{"--user", "is-active", "quickshell.service"}}, {"wallpaper", "", nil}}
	healthy := 0
	for _, check := range checks {
		if check.label == "wallpaper" {
			if _, err := os.Stat(filepath.Join(home, ".cache", "wal", "lockbg")); err == nil {
				fmt.Printf("%-12s saudável\n", check.label)
				healthy++
			} else {
				fmt.Printf("%-12s atenção\n", check.label)
			}
			continue
		}
		if _, err := exec.LookPath(check.command); err != nil {
			fmt.Printf("%-12s indisponível\n", check.label)
			continue
		}
		cmd := exec.Command(check.command, check.args...)
		cmd.Stdout, cmd.Stderr = io.Discard, io.Discard
		if cmd.Run() == nil {
			fmt.Printf("%-12s saudável\n", check.label)
			healthy++
		} else {
			fmt.Printf("%-12s atenção\n", check.label)
		}
	}
	fmt.Printf("saúde       %d/%d\n", healthy, len(checks))
	var update struct {
		Remote    string `json:"remote"`
		Available bool   `json:"update_available"`
	}
	if data, err := os.ReadFile(filepath.Join(home, ".cache", "umbra-noctis", "update.json")); err == nil && json.Unmarshal(data, &update) == nil && update.Remote != "" {
		state := "em dia"
		if update.Available {
			state = "atualização disponível: " + update.Remote
		}
		fmt.Printf("atualização  %s\n", state)
	} else {
		fmt.Println("atualização  ainda não verificada (rice check --force)")
	}
	if root, err := snapshotRoot(); err == nil {
		if entries, err := os.ReadDir(root); err == nil {
			count := 0
			for _, entry := range entries {
				if entry.IsDir() {
					count++
				}
			}
			fmt.Printf("snapshots    %d local(is)\n", count)
		}
	}
	return nil
}
