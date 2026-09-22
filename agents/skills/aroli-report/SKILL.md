---
name: aroli-report
description: >
  Use when a real Aroli Desktop product bug must reach GitHub: reproduce it,
  gather the evidence bundle, and file (or update) an issue at
  eduardoaugustolb/aroli-desktop. Triggers: file an issue, report a bug,
  report upstream, github issue, bug report, upstream fix, issue template,
  evidence bundle.
---

# Reporting upstream (gh, with consent)

File issues ONLY with the user's explicit confirmation for that exact
issue. Never file silently, never file user config mistakes as product
bugs, never paste secrets, tokens, or personal paths beyond `$HOME`.

## 1. Reproduce and bundle evidence

```sh
aroli status; cat VERSION
./diagnose 2>&1 | grep -iA2 -E "BAD|HUH"
hyprctl configerrors; systemctl --user --failed
journalctl --user -u quickshell -b --no-pager | tail -30   # if shell-related
git -C <aroli-desktop checkout> status --short; git log --oneline -3
```

State: expected vs actual in one sentence each. Include the exact
commands run and their verbatim output (trimmed, not paraphrased).

## 2. File it

```sh
gh issue create --repo eduardoaugustolb/aroli-desktop \
  --title "<area>: <symptom>" \
  --body-file /tmp/aroli-issue.md
```

Body follows `.github/ISSUE_TEMPLATE/bug_report.yml` fields: symptom,
reproduction steps, expected/actual, evidence bundle, version
(`aroli status` + checkout `VERSION`), and anything already tried.

## 3. After filing

Return the issue URL. If the fix lands in-session, reference it
(`Fixes #N`) in the commit message. If it needs upstream (Hyprland,
Quickshell, spicetify, Arch packages), say which project owns it and
file there instead, linking back.
