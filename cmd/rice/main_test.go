package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCLIAssetName(t *testing.T) {
	cases := []struct {
		goos, arch, want string
		ok               bool
	}{
		{"linux", "amd64", "rice-linux-amd64", true},
		{"linux", "arm64", "rice-linux-arm64", true},
		{"darwin", "arm64", "", false},
		{"linux", "386", "", false},
	}
	for _, test := range cases {
		got, err := cliAssetName(test.goos, test.arch)
		if (err == nil) != test.ok || got != test.want {
			t.Errorf("cliAssetName(%q, %q) = %q, %v", test.goos, test.arch, got, err)
		}
	}
}

func TestChecksumFor(t *testing.T) {
	checksum := strings.Repeat("a", 64)
	contents := checksum + "  rice-linux-amd64\n" + strings.Repeat("b", 64) + " *rice-linux-arm64\n"
	got, err := checksumFor("rice-linux-arm64", contents)
	if err != nil || got != strings.Repeat("b", 64) {
		t.Fatalf("checksumFor returned %q, %v", got, err)
	}
	if _, err := checksumFor("missing", contents); err == nil {
		t.Fatal("expected missing checksum error")
	}
	if _, err := checksumFor("bad", "short  bad\n"); err == nil {
		t.Fatal("expected malformed checksum error")
	}
}

func TestValidRepo(t *testing.T) {
	directory := t.TempDir()
	if _, err := validRepo(directory); err == nil {
		t.Fatal("directory without installer was accepted")
	}
	if err := os.WriteFile(filepath.Join(directory, "install.sh"), []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	got, err := validRepo(directory)
	if err != nil {
		t.Fatal(err)
	}
	if got != directory {
		t.Fatalf("got %q, want %q", got, directory)
	}
}

func TestEnsureRepositoryDryRunBootstrapsTemporaryCheckout(t *testing.T) {
	originalClone := cloneRepository
	originalQuietClone := cloneRepositoryQuiet
	t.Cleanup(func() { cloneRepository = originalClone; cloneRepositoryQuiet = originalQuietClone })
	cloneRepository = func(target string) error {
		if err := os.MkdirAll(target, 0o755); err != nil {
			return err
		}
		return os.WriteFile(filepath.Join(target, "install.sh"), []byte("#!/bin/sh\n"), 0o755)
	}
	cloneRepositoryQuiet = cloneRepository

	workingDirectory := t.TempDir()
	originalDirectory, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(workingDirectory); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(originalDirectory) })
	// Keep a real local installation from changing what this isolated test
	// exercises: it must reach the temporary dry-run checkout branch.
	t.Setenv("HOME", t.TempDir())

	path, cleanup, err := ensureRepositoryWithCleanup("", true)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(cleanup)
	if _, err := validRepo(path); err != nil {
		t.Fatalf("dry-run checkout is invalid: %v", err)
	}
	if !strings.HasPrefix(filepath.Base(filepath.Dir(path)), "rice-dry-run-") {
		t.Fatalf("dry-run checkout was not temporary: %q", path)
	}
	cleanup()
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("temporary checkout still exists: %v", err)
	}
}

func TestRunRejectsUnknownCommand(t *testing.T) {
	err := run([]string{"not-a-command"})
	if err == nil || !strings.Contains(err.Error(), "comando desconhecido") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestProfileByName(t *testing.T) {
	p, err := profileByName("creator")
	if err != nil || len(p.plugins) == 0 {
		t.Fatalf("creator profile = %#v, %v", p, err)
	}
	if _, err := profileByName("does-not-exist"); err == nil {
		t.Fatal("unknown profile was accepted")
	}
}

func TestCopyTreePreservesFilesAndLinks(t *testing.T) {
	source, target := t.TempDir(), filepath.Join(t.TempDir(), "snapshot")
	if err := os.WriteFile(filepath.Join(source, "theme.conf"), []byte("umbra"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(source, "nested"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(source, "nested", "colors"), []byte("violet"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("theme.conf", filepath.Join(source, "current")); err != nil {
		t.Fatal(err)
	}
	if err := copyTree(source, target); err != nil {
		t.Fatal(err)
	}
	if data, err := os.ReadFile(filepath.Join(target, "nested", "colors")); err != nil || string(data) != "violet" {
		t.Fatalf("copied data = %q, %v", data, err)
	}
	if link, err := os.Readlink(filepath.Join(target, "current")); err != nil || link != "theme.conf" {
		t.Fatalf("copied link = %q, %v", link, err)
	}
}

func TestBatteryRejectsUnknownAction(t *testing.T) {
	if err := battery([]string{"turbo"}); err == nil {
		t.Fatal("unknown battery action was accepted")
	}
}

func TestExportPreferencesCopiesOnlyPortableSettings(t *testing.T) {
	home, destination := t.TempDir(), filepath.Join(t.TempDir(), "preferences")
	t.Setenv("HOME", home)
	if err := os.MkdirAll(filepath.Join(home, ".config", "hypr"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".config", "quickshell-rice.json"), []byte(`{"language":"pt-BR"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".config", "hypr", "language.conf"), []byte("pt-BR"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := exportPreferences([]string{destination}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(destination, "aroli-preferences.json")); err != nil {
		t.Fatalf("manifest not exported: %v", err)
	}
	if data, err := os.ReadFile(filepath.Join(destination, ".config", "hypr", "language.conf")); err != nil || string(data) != "pt-BR" {
		t.Fatalf("language export = %q, %v", data, err)
	}
}
