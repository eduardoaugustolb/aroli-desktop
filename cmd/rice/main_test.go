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

func TestRunRejectsUnknownCommand(t *testing.T) {
	err := run([]string{"not-a-command"})
	if err == nil || !strings.Contains(err.Error(), "comando desconhecido") {
		t.Fatalf("unexpected error: %v", err)
	}
}
