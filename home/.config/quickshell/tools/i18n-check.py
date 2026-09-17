#!/usr/bin/env python3
"""Review the shell language layer.

    ./tools/i18n-check.py            everything
    ./tools/i18n-check.py --missing  only what has no translation

Four things, which are the four ways to break this:

  1. strings wrapped in I18n.tr() that are missing from translations-es.js
     or translations-pt-BR.js
     -> they would show up in English with the shell in Spanish/Portuguese;
  2. dictionary entries nobody uses anymore
     -> garbage that survives a text change and misleads whoever comes next;
  3. {0} {1} {2} slots dropped or invented in a translation
     -> the number, the name or the percentage disappears from the sentence;
  4. visible literals (text/label/hint/title/...) still NOT wrapped
     -> the bit of interface someone forgot.

Exit 0 when everything is fine, 1 when there is something to look at.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.dirname(HERE)

# Properties whose value ends up on screen. `icon` and `value` are not there:
# the first is glyphs and the second is almost always data, not a sentence.
VISIBLES = ("text", "label", "hint", "title", "note", "body", "placeholderText",
            "actionText", "subtitle", "description", "tooltip")

# Strings deliberately NOT translated. Each carries its reason because in a
# year nobody will remember, and without this the review always comes out with
# a handful of false complaints and ends up ignored by everyone.
ON_PURPOSE = {
    ("I18n.qml", "Español"):
        "the language is offered in its own language, so it can be found",
    ("I18n.qml", "Português (Brasil)"):
        "same as above",
    ("I18n.qml", "English"):
        "same as above",
    ("SettingsWindow.qml", "Settings"):
        "it is the window title the hyprland.lua windowrule matches "
        "(title = ^(Settings)$) plus the SettingsWindow focus: translating it "
        "leaves the window unfloated and unfocused",
    ("MediaControls.qml", "Toggle media controls"):
        "description of a GlobalShortcut: not shown in the shell, only in "
        "hyprctl globalshortcuts, and already in English",
    ("WallpaperPicker.qml", "Wallpaper picker"):
        "same as above",
}

# What looks like a sentence but is not one. When a string matches this, it is
# not reported as missing a translation.
NOT_TEXT = re.compile(r"""
      ^\s*$                     # empty
    | ^[\W\d_]+$                # symbols, glyphs or numbers only
    | ^[~/.]                    # paths: ~/.config/..., ./something, /etc/...
    | ^[a-z0-9_-]+$             # bare identifiers: "network", "wifi-off"
    | ^\#[0-9a-fA-F]{3,8}$      # colors (the \# is mandatory: in VERBOSE mode
                                # a bare hash opens a comment and swallows
                                # the rest of the alternative)
    | ^[A-Z][a-z]+\ [A-Z]       # proper font names: "Adwaita Sans"
    | ^\{                       # a lone slot
""", re.VERBOSE)

RE_TR = re.compile(r'I18n\.tr\(\s*"((?:[^"\\]|\\.)*)"')
RE_VIS = re.compile(
    r'\b(' + "|".join(VISIBLES) + r')\s*:\s*"((?:[^"\\]|\\.)*)"')
RE_ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')
RE_SLOT = re.compile(r"\{[012]\}")


def qmls():
    for name in sorted(os.listdir(SHELL)):
        if name.endswith(".qml"):
            yield name, os.path.join(SHELL, name)


def dynamic_keys():
    """Keys that do NOT show up as I18n.tr("literal") in any .qml.

    Right now those are the shortcut descriptions: SettingsShortcuts reads the
    comments on the `bind =` lines of hyprland.conf and passes them through
    I18n.tr(comment), with the variable inside. Without this the review would
    report them as dead entries and someone would end up deleting them.
    """
    # FIRST the hyprland.conf next to this script, and only when it is missing
    # the one in $HOME. The other way around — which is how it was — reviewed
    # the repo against the system's OLD live config before installing: the
    # shortcuts you just added showed up as dead entries and the ones you
    # removed never showed.
    conf = os.path.join(os.path.dirname(os.path.dirname(SHELL)),
                        "hypr", "hyprland.conf")
    if not os.path.exists(conf):
        conf = os.path.expanduser("~/.config/hypr/hyprland.conf")
    out = set()
    if not os.path.exists(conf):
        return out
    with open(conf, encoding="utf-8") as f:
        for line in f:
            m = re.match(r'^\s*bind[a-z]*\s*=\s*(.+)$', line.strip())
            if not m:
                continue
            rest = m.group(1)
            i = rest.find("#")
            if i >= 0 and rest[i + 1:].strip():
                out.add(rest[i + 1:].strip())
    return out


def dictionary(varname, filename):
    """The entries of a translations-*.js dictionary, without evaluating JS."""
    path = os.path.join(SHELL, filename)
    dic, doubles = {}, []
    inside = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip().startswith("var " + varname):
                inside = True
                continue
            if not inside:
                continue
            if line.strip().startswith("};"):
                break
            m = RE_ENTRY.match(line)
            if m:
                key, value = m.group(1), m.group(2)
                if key in dic:
                    doubles.append(key)
                dic[key] = value
    return dic, doubles


def main():
    only_missing = "--missing" in sys.argv or "--faltan" in sys.argv
    es, es_doubles = dictionary("es", "translations-es.js")
    pt, pt_doubles = dictionary("ptBR", "translations-pt-BR.js")

    used = {}        # string -> files where it is used
    unwrapped = {}   # file -> [strings]

    for name, path in qmls():
        with open(path, encoding="utf-8") as f:
            text = f.read()
        for m in RE_TR.finditer(text):
            used.setdefault(m.group(1), set()).add(name)
        # a visible literal NOT sitting inside an I18n.tr(
        for m in RE_VIS.finditer(text):
            raw = m.group(2)
            before = text[max(0, m.start() - 40):m.start(2)]
            if "I18n.tr(" in before[-30:]:
                continue
            if NOT_TEXT.search(raw):
                continue
            if (name, raw) in ON_PURPOSE:
                continue
            unwrapped.setdefault(name, []).append(raw)

    for s in dynamic_keys():
        used.setdefault(s, set()).add("hyprland.conf")

    missing_es = sorted(s for s in used if s not in es)
    missing_pt = sorted(s for s in used if s not in pt)
    dead_es = sorted(k for k in es if k not in used)
    dead_pt = sorted(k for k in pt if k not in used)
    key_drift = sorted(set(es) ^ set(pt))
    slots = []
    for label, dic in (("es", es), ("pt-BR", pt)):
        for key, value in dic.items():
            if sorted(RE_SLOT.findall(key)) != sorted(RE_SLOT.findall(value)):
                slots.append((label, key))

    print(f"  {len(used)} wrapped strings · "
          f"{len(es)} Spanish · {len(pt)} Portuguese")

    if missing_es:
        print(f"\n  UNTRANSLATED TO SPANISH ({len(missing_es)}) — "
              f"they would show up in English:")
        for s in missing_es:
            print(f'    {sorted(used[s])[0]:24} "{s}"')
    if missing_pt:
        print(f"\n  UNTRANSLATED TO PORTUGUESE ({len(missing_pt)}) — "
              f"they would show up in English:")
        for s in missing_pt:
            print(f'    {sorted(used[s])[0]:24} "{s}"')
    if only_missing:
        return 1 if (missing_es or missing_pt) else 0

    if key_drift:
        print(f"\n  KEYS IN ONE DICTIONARY ONLY ({len(key_drift)}):")
        for s in key_drift:
            print(f'    "{s}"')
    if slots:
        print(f"\n  MISMATCHED SLOTS ({len(slots)}):")
        for label, s in sorted(slots):
            print(f'    [{label}] "{s}"\n'
                  f'      -> "{es[s] if label == "es" else pt[s]}"')
    if es_doubles:
        print(f"\n  DUPLICATE KEYS, es ({len(es_doubles)}):")
        for s in sorted(set(es_doubles)):
            print(f'    "{s}"')
    if pt_doubles:
        print(f"\n  DUPLICATE KEYS, pt-BR ({len(pt_doubles)}):")
        for s in sorted(set(pt_doubles)):
            print(f'    "{s}"')
    if dead_es:
        print(f"\n  DEAD ENTRIES, es ({len(dead_es)}) — nobody uses them:")
        for s in dead_es:
            print(f'    "{s}"')
    if dead_pt:
        print(f"\n  DEAD ENTRIES, pt-BR ({len(dead_pt)}) — nobody uses them:")
        for s in dead_pt:
            print(f'    "{s}"')
    if unwrapped:
        total = sum(len(v) for v in unwrapped.values())
        print(f"\n  VISIBLE LITERALS NOT WRAPPED ({total}):")
        for name in sorted(unwrapped):
            for s in unwrapped[name]:
                print(f'    {name:24} "{s}"')

    bad = bool(missing_es or missing_pt or key_drift or slots or es_doubles
               or pt_doubles or unwrapped)
    print("\n  all good" if not bad else "")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
