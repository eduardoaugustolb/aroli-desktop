// rice is the supported command-line interface for Umbra Noctis.
//
// The installer itself deliberately remains a compatibility backend for now:
// it contains years of idempotency and backup rules. This program owns the
// public interface, bootstrap flow and beginner-friendly terminal menu.
package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

const (
	project       = "Umbra Noctis"
	repositoryURL = "https://github.com/eduardoaugustolb/umbra-noctis.git"
	defaultLang   = "pt-BR"
)

var version = "dev" // set with -ldflags "-X main.version=vX.Y.Z"

type installOptions struct {
	dryRun, yes, copy, resume bool
	lang                      string
	phases                    []string
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "rice:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return tui()
	}
	switch args[0] {
	case "install":
		return install(args[1:])
	case "plugins", "plugin":
		return plugins(args[1:])
	case "logs":
		return showLogs(args[1:])
	case "cli":
		return updateCLI(args[1:])
	case "diagnose":
		return runBackend("diagnose", args[1:])
	case "version":
		fmt.Println(cliVersion())
		return nil
	case "help", "--help", "-h":
		usage(os.Stdout)
		return nil
	case "status", "check", "update", "rollback", "prune":
		return runBackend("rice", args)
	default:
		return fmt.Errorf("comando desconhecido %q (use 'rice help')", args[0])
	}
}

func usage(w io.Writer) {
	fmt.Fprintf(w, `%s CLI

Uso:
  rice                     abre o assistente interativo
  rice install [opções] [fase...]
  rice diagnose
  rice logs [--list]         mostra o registro da instalação mais recente
  rice cli update [--dry-run] atualiza somente o binário da CLI
  rice plugins list|install [opções] [nome...]
  rice status | check | update | rollback | prune

Instalação:
  --dry-run                mostra o plano, sem alterar nada
  --yes                    não pergunta confirmações
  --copy                   copia os arquivos em vez de criar links
  --link                   cria links para o checkout (padrão)
  --lang pt-BR|en|es       idioma da interface
  --repo CAMINHO           usa este checkout em vez do gerenciado pela CLI
  --resume                 continua uma instalação interrompida

Opcionais:
  rice plugins list         mostra apps e ferramentas que podem ser adicionadas
  rice plugins install NOME instala somente os itens escolhidos

Fases: base, aur, packages, repos, cursor, config, system, graphics,
       services, sddm, spicetify, final ou restore.

Exemplos:
  rice install --dry-run
  rice install --lang pt-BR
  rice install packages services
  rice update --dry-run
`, project)
}

func install(args []string) error {
	fs := flag.NewFlagSet("install", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	var opts installOptions
	var repo string
	fs.BoolVar(&opts.dryRun, "dry-run", false, "não faz alterações")
	fs.BoolVar(&opts.dryRun, "n", false, "não faz alterações")
	fs.BoolVar(&opts.yes, "yes", false, "não pede confirmação")
	fs.BoolVar(&opts.yes, "y", false, "não pede confirmação")
	fs.BoolVar(&opts.copy, "copy", false, "copia em vez de criar links")
	fs.BoolVar(&opts.resume, "resume", false, "retoma a última instalação interrompida")
	fs.Bool("link", false, "cria links (padrão)")
	fs.StringVar(&opts.lang, "lang", defaultLang, "pt-BR, en ou es")
	fs.StringVar(&repo, "repo", "", "checkout do rice")
	fs.Usage = func() { usage(fs.Output()) }
	if err := fs.Parse(args); err != nil {
		return err
	}
	if opts.lang != "pt-BR" && opts.lang != "en" && opts.lang != "es" {
		return errors.New("--lang aceita apenas pt-BR, en ou es")
	}
	opts.phases = fs.Args()
	if !opts.dryRun {
		if err := installSelf(); err != nil {
			return err
		}
	}
	path, cleanup, err := ensureRepositoryWithCleanup(repo, opts.dryRun)
	if err != nil {
		return err
	}
	defer cleanup()
	backend := []string{"--lang", opts.lang}
	if opts.dryRun {
		backend = append(backend, "--dry-run")
	}
	if opts.yes {
		backend = append(backend, "--yes")
	}
	if opts.copy {
		backend = append(backend, "--copy")
	}
	if opts.resume {
		backend = append(backend, "--resume")
	}
	backend = append(backend, opts.phases...)
	fmt.Printf("\n%s será instalado a partir de:\n  %s\n\n", project, path)
	return command(path, "bash", append([]string{"install.sh"}, backend...)...).Run()
}

// ensureRepository makes a CLI installation useful even when the user has
// never cloned the dotfiles repository. Existing checkouts always win.
func ensureRepository(explicit string, dryRun bool) (string, error) {
	path, _, err := ensureRepositoryWithCleanup(explicit, dryRun)
	return path, err
}

func ensureRepositoryWithCleanup(explicit string, dryRun bool) (string, func(), error) {
	noCleanup := func() {}
	if explicit != "" {
		path, err := validRepo(explicit)
		return path, noCleanup, err
	}
	if env := os.Getenv("UMBRA_RICE_REPO"); env != "" {
		if path, err := validRepo(env); err == nil {
			return path, noCleanup, nil
		}
	}
	if cwd, err := os.Getwd(); err == nil {
		if path, err := validRepo(cwd); err == nil {
			return path, noCleanup, nil
		}
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", noCleanup, err
	}
	target := filepath.Join(home, ".local", "share", "umbra-noctis")
	if path, err := validRepo(target); err == nil {
		return path, noCleanup, nil
	}
	if dryRun {
		parent, err := os.MkdirTemp("", "rice-dry-run-")
		if err != nil {
			return "", noCleanup, err
		}
		dryRunTarget := filepath.Join(parent, "checkout")
		if err := cloneRepository(dryRunTarget); err != nil {
			_ = os.RemoveAll(parent)
			return "", noCleanup, fmt.Errorf("não foi possível preparar o rice para o dry-run: %w", err)
		}
		return dryRunTarget, func() { _ = os.RemoveAll(parent) }, nil
	}
	if _, err := exec.LookPath("git"); err != nil {
		return "", noCleanup, errors.New("git é necessário para baixar o rice")
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return "", noCleanup, err
	}
	fmt.Println("Baixando o rice pela primeira vez…")
	if err := cloneRepository(target); err != nil {
		return "", noCleanup, fmt.Errorf("não foi possível baixar o rice: %w", err)
	}
	path, err := validRepo(target)
	return path, noCleanup, err
}

var cloneRepository = func(target string) error {
	return command("", "git", "clone", "--depth", "1", repositoryURL, target).Run()
}

func validRepo(path string) (string, error) {
	path, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	if info, err := os.Stat(filepath.Join(path, "install.sh")); err != nil || info.IsDir() {
		return "", fmt.Errorf("%s não parece ser um checkout do Umbra Noctis", path)
	}
	return path, nil
}

// installSelf keeps ~/.local/bin/rice under the CLI's control. The dotfile
// deployment intentionally skips that filename so an upgrade cannot replace
// the binary with the historical shell dispatcher.
func installSelf() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	if runtime.GOOS == "windows" {
		return nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	dest := filepath.Join(home, ".local", "bin", "rice")
	if sameFile(exe, dest) {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return err
	}
	src, err := os.Open(exe)
	if err != nil {
		return err
	}
	defer src.Close()
	tmp, err := os.CreateTemp(filepath.Dir(dest), ".rice-")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if _, err = io.Copy(tmp, src); err == nil {
		err = tmp.Chmod(0o755)
	}
	if closeErr := tmp.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(tmpName, dest)
}

func sameFile(a, b string) bool {
	aInfo, aErr := os.Stat(a)
	bInfo, bErr := os.Stat(b)
	return aErr == nil && bErr == nil && os.SameFile(aInfo, bInfo)
}

func runBackend(kind string, args []string) error {
	repo, cleanup, err := ensureRepositoryWithCleanup("", true)
	if err != nil {
		return err
	}
	defer cleanup()
	if _, err := validRepo(repo); err != nil {
		return errors.New("rice ainda não foi instalado; execute: rice install")
	}
	if kind == "diagnose" {
		return command(repo, "bash", append([]string{"diagnose"}, args...)...).Run()
	}
	legacy := filepath.Join(repo, "home", ".local", "bin", "rice")
	if _, err := os.Stat(legacy); err != nil {
		return fmt.Errorf("backend de atualização ausente: %w", err)
	}
	return command(repo, "bash", append([]string{legacy}, args...)...).Run()
}

func command(dir, name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd
}

func cliVersion() string {
	if version != "dev" {
		return strings.TrimPrefix(version, "v")
	}
	if repo, err := validRepo("."); err == nil {
		if data, err := os.ReadFile(filepath.Join(repo, "VERSION")); err == nil {
			return strings.TrimSpace(string(data))
		}
	}
	return version
}

func showLogs(args []string) error {
	if len(args) > 1 || (len(args) == 1 && args[0] != "--list") {
		return errors.New("use: rice logs [--list]")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	directory := filepath.Join(home, ".local", "state", "umbra-noctis")
	files, err := filepath.Glob(filepath.Join(directory, "install-*.log"))
	if err != nil {
		return err
	}
	if len(files) == 0 {
		return errors.New("ainda não há logs de instalação")
	}
	sort.Slice(files, func(i, j int) bool { return files[i] > files[j] })
	if len(args) == 1 {
		for _, file := range files {
			fmt.Println(file)
		}
		return nil
	}
	data, err := os.ReadFile(files[0])
	if err != nil {
		return err
	}
	lines := strings.Split(string(data), "\n")
	if len(lines) > 100 {
		lines = lines[len(lines)-100:]
	}
	fmt.Printf("Último log: %s\n\n", files[0])
	fmt.Println(strings.Join(lines, "\n"))
	return nil
}

const githubAPIRelease = "https://api.github.com/repos/eduardoaugustolb/umbra-noctis/releases/latest"

type githubRelease struct {
	TagName string `json:"tag_name"`
}

func updateCLI(args []string) error {
	if len(args) == 0 || args[0] != "update" {
		return errors.New("use: rice cli update [--dry-run]")
	}
	fs := flag.NewFlagSet("cli update", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	dryRun := fs.Bool("dry-run", false, "consulta a versão sem substituir o binário")
	if err := fs.Parse(args[1:]); err != nil {
		return err
	}
	if len(fs.Args()) > 0 {
		return errors.New("use: rice cli update [--dry-run]")
	}

	release, err := latestRelease(http.DefaultClient)
	if err != nil {
		return err
	}
	asset, err := cliAssetName(runtime.GOOS, runtime.GOARCH)
	if err != nil {
		return err
	}
	base := "https://github.com/eduardoaugustolb/umbra-noctis/releases/download/" + release.TagName + "/"
	fmt.Printf("CLI atual: %s\nDisponível: %s\n", cliVersion(), strings.TrimPrefix(release.TagName, "v"))
	if *dryRun {
		fmt.Printf("seria baixado e verificado: %s%s\n", base, asset)
		return nil
	}

	checksums, err := download(http.DefaultClient, base+"SHA256SUMS.txt")
	if err != nil {
		return err
	}
	expected, err := checksumFor(asset, string(checksums))
	if err != nil {
		return err
	}
	binary, err := download(http.DefaultClient, base+asset)
	if err != nil {
		return err
	}
	actual := fmt.Sprintf("%x", sha256.Sum256(binary))
	if !strings.EqualFold(expected, actual) {
		return errors.New("a verificação de integridade falhou; a CLI não foi alterada")
	}
	if err := installDownloadedCLI(binary); err != nil {
		return err
	}
	fmt.Printf("Pronto! A CLI foi atualizada para %s.\n", strings.TrimPrefix(release.TagName, "v"))
	return nil
}

func latestRelease(client *http.Client) (githubRelease, error) {
	request, err := http.NewRequest(http.MethodGet, githubAPIRelease, nil)
	if err != nil {
		return githubRelease{}, err
	}
	request.Header.Set("Accept", "application/vnd.github+json")
	response, err := client.Do(request)
	if err != nil {
		return githubRelease{}, fmt.Errorf("não foi possível verificar atualizações da CLI: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return githubRelease{}, fmt.Errorf("GitHub respondeu %s ao consultar a CLI", response.Status)
	}
	var release githubRelease
	if err := json.NewDecoder(io.LimitReader(response.Body, 1<<20)).Decode(&release); err != nil {
		return githubRelease{}, err
	}
	if release.TagName == "" {
		return githubRelease{}, errors.New("a release mais recente não possui uma tag")
	}
	return release, nil
}

func cliAssetName(goos, arch string) (string, error) {
	if goos != "linux" || (arch != "amd64" && arch != "arm64") {
		return "", fmt.Errorf("não há binário publicado para %s/%s", goos, arch)
	}
	return "rice-linux-" + arch, nil
}

func download(client *http.Client, url string) ([]byte, error) {
	clientCopy := *client
	if clientCopy.Timeout == 0 {
		clientCopy.Timeout = 30 * time.Second
	}
	response, err := clientCopy.Get(url)
	if err != nil {
		return nil, fmt.Errorf("não foi possível baixar %s: %w", url, err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("download falhou: %s", response.Status)
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, 100<<20))
	if err != nil {
		return nil, err
	}
	return data, nil
}

func checksumFor(asset, contents string) (string, error) {
	for _, line := range strings.Split(contents, "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 && strings.TrimPrefix(fields[len(fields)-1], "*") == asset {
			if len(fields[0]) != 64 {
				return "", fmt.Errorf("checksum inválido para %s", asset)
			}
			return fields[0], nil
		}
	}
	return "", fmt.Errorf("a release não publicou checksum para %s", asset)
}

func installDownloadedCLI(binary []byte) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	destination := filepath.Join(home, ".local", "bin", "rice")
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(destination), ".rice-download-")
	if err != nil {
		return err
	}
	name := temporary.Name()
	defer os.Remove(name)
	if _, err = temporary.Write(binary); err == nil {
		err = temporary.Chmod(0o755)
	}
	if closeErr := temporary.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(name, destination)
}

type plugin struct {
	name, description, source string
}

func plugins(args []string) error {
	if len(args) == 0 || args[0] == "list" {
		items, err := pluginCatalog()
		if err != nil {
			return err
		}
		fmt.Println("\nAplicativos e ferramentas opcionais")
		fmt.Println("Nada abaixo é necessário para o Umbra funcionar. Instale só o que fizer sentido para você.")
		for _, item := range items {
			fmt.Printf("  %-30s %-7s %s\n", item.name, item.source, item.description)
		}
		return nil
	}
	if args[0] != "install" {
		return errors.New("use: rice plugins list ou rice plugins install NOME")
	}
	fs := flag.NewFlagSet("plugins install", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	dry := fs.Bool("dry-run", false, "mostra o que seria instalado")
	yes := fs.Bool("yes", false, "não pede confirmação")
	if err := fs.Parse(args[1:]); err != nil {
		return err
	}
	if len(fs.Args()) == 0 {
		return errors.New("escolha pelo menos um nome; veja as opções com: rice plugins list")
	}
	items, err := pluginCatalog()
	if err != nil {
		return err
	}
	chosen := make([]plugin, 0, len(fs.Args()))
	for _, name := range fs.Args() {
		found := false
		for _, item := range items {
			if item.name == name {
				chosen = append(chosen, item)
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("%q não é um opcional conhecido; use: rice plugins list", name)
		}
	}
	if !*yes && !*dry {
		fmt.Println("\nVocê escolheu:")
		for _, item := range chosen {
			fmt.Printf("  • %s — %s\n", item.name, item.description)
		}
		if !confirm(bufio.NewReader(os.Stdin), "Instalar estes itens agora?") {
			fmt.Println("Tudo bem, nada foi instalado.")
			return nil
		}
	}
	return installPlugins(chosen, *dry)
}

func pluginCatalog() ([]plugin, error) {
	repo, cleanup, err := ensureRepositoryWithCleanup("", true)
	if err != nil {
		return nil, err
	}
	defer cleanup()
	if _, err := validRepo(repo); err != nil {
		return nil, errors.New("instale o rice antes de gerenciar opcionais: rice install")
	}
	items := []plugin{}
	for _, manifest := range []struct{ file, source string }{{"optional-pacman.txt", "oficial"}, {"optional-aur.txt", "AUR"}} {
		file, err := os.Open(filepath.Join(repo, "packages", manifest.file))
		if err != nil {
			return nil, err
		}
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			parts := strings.SplitN(line, "\t", 2)
			item := plugin{name: strings.TrimSpace(parts[0]), source: manifest.source}
			if len(parts) == 2 {
				item.description = strings.TrimSpace(parts[1])
			}
			items = append(items, item)
		}
		if err := scanner.Err(); err != nil {
			file.Close()
			return nil, err
		}
		file.Close()
	}
	return items, nil
}

func installPlugins(items []plugin, dry bool) error {
	official, aur := []string{}, []string{}
	for _, item := range items {
		if item.source == "AUR" {
			aur = append(aur, item.name)
		} else {
			official = append(official, item.name)
		}
	}
	if dry {
		if len(official) > 0 {
			fmt.Printf("seria instalado dos repositórios oficiais: %s\n", strings.Join(official, ", "))
		}
		if len(aur) > 0 {
			fmt.Printf("seria instalado do AUR: %s\n", strings.Join(aur, ", "))
		}
		return nil
	}
	if len(official) > 0 {
		if _, err := exec.LookPath("omarchy-pkg-add"); err == nil {
			if err := installWith("omarchy-pkg-add", official); err != nil {
				return err
			}
		} else {
			args := append([]string{"env", "OMARCHY_ALLOW_DIRECT_PACMAN=1", "pacman", "-S", "--needed", "--noconfirm", "--"}, official...)
			if err := command("", "sudo", args...).Run(); err != nil {
				return fmt.Errorf("não foi possível instalar os itens oficiais: %w", err)
			}
		}
	}
	if len(aur) > 0 {
		if _, err := exec.LookPath("omarchy-pkg-aur-add"); err == nil {
			if err := installWith("omarchy-pkg-aur-add", aur); err != nil {
				return err
			}
		} else {
			if _, err := exec.LookPath("yay"); err != nil {
				return errors.New("estes itens vêm do AUR, mas o yay não está instalado. Rode: rice install aur")
			}
			args := append([]string{"-S", "--needed", "--noconfirm", "--"}, aur...)
			if err := command("", "yay", args...).Run(); err != nil {
				return fmt.Errorf("não foi possível instalar os itens do AUR: %w", err)
			}
		}
	}
	fmt.Println("\nPronto! Os itens escolhidos foram instalados.")
	return nil
}

func installWith(manager string, packages []string) error {
	for _, pkg := range packages {
		if err := command("", manager, pkg).Run(); err != nil {
			return fmt.Errorf("%s não conseguiu instalar %s: %w", manager, pkg, err)
		}
	}
	return nil
}

func confirm(reader *bufio.Reader, question string) bool {
	fmt.Printf("%s [s/N] ", question)
	answer, _ := reader.ReadString('\n')
	answer = strings.ToLower(strings.TrimSpace(answer))
	return answer == "s" || answer == "sim" || answer == "y" || answer == "yes"
}

func guidedPlugins(in *bufio.Reader) error {
	items, err := pluginCatalog()
	if err != nil {
		return err
	}
	fmt.Println("\nVocê pode adicionar estes extras depois, quando quiser. Eles não são necessários para o desktop funcionar.")
	for index, item := range items {
		fmt.Printf("%2d) %-26s %s [%s]\n", index+1, item.name, item.description, item.source)
	}
	fmt.Print("\nDigite os números separados por vírgula (ou Enter para voltar): ")
	selection, _ := in.ReadString('\n')
	selection = strings.TrimSpace(selection)
	if selection == "" {
		return nil
	}
	names := []string{}
	for _, value := range strings.Split(selection, ",") {
		var index int
		if _, err := fmt.Sscan(strings.TrimSpace(value), &index); err != nil || index < 1 || index > len(items) {
			return errors.New("use apenas números que aparecem na lista")
		}
		names = append(names, items[index-1].name)
	}
	fmt.Printf("Você selecionou: %s\n", strings.Join(names, ", "))
	if confirm(in, "Ver o plano sem instalar?") {
		return plugins(append([]string{"install", "--dry-run"}, names...))
	}
	if !confirm(in, "Confirmar a instalação?") {
		fmt.Println("Tudo bem, nada foi instalado.")
		return nil
	}
	return plugins(append([]string{"install", "--yes"}, names...))
}

type tuiScreen uint8

const (
	tuiHome tuiScreen = iota
	tuiLanguage
	tuiPlugins
	tuiConfirm
	tuiRunning
	tuiDone
)

type tuiAction struct {
	label, hint string
	command     func(*tuiModel) error
}

type tuiResult struct{ err error }

type tuiModel struct {
	screen       tuiScreen
	cursor       int
	pluginCursor int
	action       int
	language     string
	dryRun       bool
	plugins      []plugin
	selected     map[int]bool
	message      string
	width        int
	height       int
}

var (
	tuiTitle    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#F2CC8F"))
	tuiAccent   = lipgloss.NewStyle().Foreground(lipgloss.Color("#81B29A"))
	tuiMuted    = lipgloss.NewStyle().Foreground(lipgloss.Color("#8D99AE"))
	tuiSelected = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#F2CC8F"))
	tuiPanel    = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("#3D405B")).Padding(1, 2)
)

func newTUIModel() tuiModel {
	return tuiModel{language: defaultLang, selected: map[int]bool{}}
}

func (m tuiModel) actions() []tuiAction {
	return []tuiAction{
		{label: "Instalar ou reparar", hint: "aplicar o rice no sistema", command: func(m *tuiModel) error { return install([]string{"--yes", "--lang", m.language}) }},
		{label: "Ver plano de instalação", hint: "simular sem alterar arquivos", command: func(m *tuiModel) error { return install([]string{"--dry-run", "--yes", "--lang", m.language}) }},
		{label: "Adicionar plugins", hint: "escolher aplicativos oficiais e AUR", command: nil},
		{label: "Diagnosticar", hint: "verificar problemas conhecidos", command: func(*tuiModel) error { return runBackend("diagnose", nil) }},
		{label: "Verificar atualizações", hint: "consultar a versão estável", command: func(*tuiModel) error { return runBackend("rice", []string{"check", "--force"}) }},
		{label: "Atualizar rice", hint: "aplicar a versão estável mais recente", command: func(*tuiModel) error { return runBackend("rice", []string{"update"}) }},
		{label: "Atualizar CLI", hint: "baixar a CLI com checksum SHA-256", command: func(*tuiModel) error { return updateCLI([]string{"update"}) }},
		{label: "Ver último log", hint: "abrir o registro da instalação", command: func(*tuiModel) error { return showLogs(nil) }},
	}
}

func tui() error {
	if !termIsInteractive() {
		return errors.New("a TUI precisa de um terminal interativo; use 'rice help' para os comandos")
	}
	_, err := tea.NewProgram(newTUIModel(), tea.WithAltScreen()).Run()
	return err
}

func termIsInteractive() bool {
	info, err := os.Stdout.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

func (m tuiModel) Init() tea.Cmd { return nil }

func (m tuiModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tuiResult:
		m.screen = tuiDone
		if msg.err != nil {
			m.message = "Erro: " + msg.err.Error()
		} else {
			m.message = "Ação concluída com sucesso."
		}
	case tea.KeyMsg:
		key := msg.String()
		if key == "ctrl+c" || key == "q" || key == "esc" {
			if m.screen == tuiHome || m.screen == tuiDone {
				return m, tea.Quit
			}
			m.screen = tuiHome
			return m, nil
		}
		switch m.screen {
		case tuiHome:
			return m.updateHome(key)
		case tuiLanguage:
			return m.updateLanguage(key)
		case tuiPlugins:
			return m.updatePlugins(key)
		case tuiConfirm:
			if key == "y" || key == "enter" {
				m.screen = tuiRunning
				return m, m.runAction()
			}
			if key == "n" || key == "backspace" {
				m.screen = tuiHome
			}
		case tuiDone:
			if key == "enter" || key == "r" {
				m.screen = tuiHome
			}
		}
	}
	return m, nil
}

func (m tuiModel) updateHome(key string) (tea.Model, tea.Cmd) {
	actions := m.actions()
	switch key {
	case "up", "k":
		m.cursor = (m.cursor + len(actions) - 1) % len(actions)
	case "down", "j":
		m.cursor = (m.cursor + 1) % len(actions)
	case "enter", "1", "2", "3", "4", "5", "6", "7", "8":
		if key != "enter" {
			m.cursor = int(key[0] - '1')
		}
		m.action = m.cursor
		if m.cursor == 0 || m.cursor == 1 {
			m.dryRun = m.cursor == 1
			m.screen = tuiLanguage
		} else if m.cursor == 2 {
			items, err := pluginCatalog()
			if err != nil {
				m.message = "Erro: " + err.Error()
				m.screen = tuiDone
			} else {
				m.plugins, m.selected, m.pluginCursor = items, map[int]bool{}, 0
				m.screen = tuiPlugins
			}
		} else {
			m.screen = tuiConfirm
		}
	}
	return m, nil
}

func (m tuiModel) updateLanguage(key string) (tea.Model, tea.Cmd) {
	langs := []string{"pt-BR", "en", "es"}
	var index int
	for i, lang := range langs {
		if lang == m.language {
			index = i
		}
	}
	switch key {
	case "left", "h", "up":
		index = (index + len(langs) - 1) % len(langs)
	case "right", "l", "down":
		index = (index + 1) % len(langs)
	case "enter":
		m.language, m.screen = langs[index], tuiConfirm
	}
	if key != "enter" {
		m.language = langs[index]
	}
	return m, nil
}

func (m tuiModel) updatePlugins(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "up", "k":
		m.pluginCursor = (m.pluginCursor + len(m.plugins) - 1) % len(m.plugins)
	case "down", "j":
		m.pluginCursor = (m.pluginCursor + 1) % len(m.plugins)
	case "space":
		m.selected[m.pluginCursor] = !m.selected[m.pluginCursor]
	case "enter":
		if len(m.selectedPlugins()) == 0 {
			m.message = "Selecione pelo menos um plugin com espaço."
			return m, nil
		}
		m.screen = tuiConfirm
	}
	return m, nil
}

func (m tuiModel) selectedPlugins() []plugin {
	items := []plugin{}
	for i, item := range m.plugins {
		if m.selected[i] {
			items = append(items, item)
		}
	}
	return items
}

func (m tuiModel) runAction() tea.Cmd {
	return func() tea.Msg {
		var err error
		if m.action == 2 {
			err = installPlugins(m.selectedPlugins(), false)
		} else {
			err = m.actions()[m.action].command(&m)
		}
		return tuiResult{err: err}
	}
}

func (m tuiModel) View() string {
	var body string
	switch m.screen {
	case tuiHome:
		body = m.viewHome()
	case tuiLanguage:
		body = m.viewLanguage()
	case tuiPlugins:
		body = m.viewPlugins()
	case tuiConfirm:
		body = m.viewConfirm()
	case tuiRunning:
		body = "\n  Executando…\n"
	case tuiDone:
		body = tuiTitle.Render("\n  "+m.message+"\n\n") + tuiMuted.Render("  Enter/r: voltar   q: sair")
	}
	return tuiPanel.Render(tuiTitle.Render("Umbra Noctis") + "\n" + tuiMuted.Render("rice · assistente") + "\n\n" + body + "\n\n" + tuiMuted.Render("↑/↓ navegar · Enter selecionar · q sair"))
}

func (m tuiModel) viewHome() string {
	lines := []string{}
	for i, action := range m.actions() {
		prefix := "  "
		if i == m.cursor {
			prefix = tuiAccent.Render("› ")
		}
		lines = append(lines, prefix+tuiSelected.Render(fmt.Sprintf("%d. %-25s", i+1, action.label))+"  "+tuiMuted.Render(action.hint))
	}
	return strings.Join(lines, "\n")
}

func (m tuiModel) viewLanguage() string {
	return "\n  Idioma da instalação\n\n  " + tuiSelected.Render("‹  "+m.language+"  ›") + "\n\n  Use ←/→ e confirme com Enter."
}

func (m tuiModel) viewPlugins() string {
	lines := []string{"\n  Plugins opcionais · Espaço marca, Enter confirma", ""}
	for i, item := range m.plugins {
		mark := "○"
		if m.selected[i] {
			mark = tuiAccent.Render("●")
		}
		prefix := "  "
		if i == m.pluginCursor {
			prefix = tuiAccent.Render("› ")
		}
		lines = append(lines, prefix+mark+" "+item.name+"  "+tuiMuted.Render(item.source+" · "+item.description))
	}
	return strings.Join(lines, "\n")
}

func (m tuiModel) viewConfirm() string {
	action := m.actions()[m.action].label
	if m.action == 2 {
		action = fmt.Sprintf("instalar %d plugin(s)", len(m.selectedPlugins()))
	}
	if m.dryRun {
		action += " (simulação)"
	}
	return "\n  Confirmar: " + tuiSelected.Render(action) + "\n\n  " + tuiAccent.Render("Enter/y") + " executar    " + tuiMuted.Render("n voltar")
}

func guidedInstall(in *bufio.Reader, dryRun bool) error {
	fmt.Printf("Idioma [pt-BR/en/es] (%s): ", defaultLang)
	lang, _ := in.ReadString('\n')
	lang = strings.TrimSpace(lang)
	if lang == "" {
		lang = defaultLang
	}
	args := []string{"--lang", lang}
	if dryRun {
		args = append(args, "--dry-run")
	}
	return install(args)
}
