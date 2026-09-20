#!/usr/bin/env python3
"""Scan the ROM folders and write roms.json for the Chalk Console.

Run it from the site root after adding or renaming games:

    python tools/scan_roms.py

Cloudflare can run it on every deploy: set the Pages build command to
    python tools/scan_roms.py
so pushing a new ROM is all you have to do.

Layout is up to you. Both of these are found:

    NES/micromages.nes
    NES/Micro Mages/micromages.nes      <- folder per game

A picture next to the ROM (cover.png, or same name as the ROM) becomes its
thumbnail in the list. The game's name comes from the folder when there is
one, otherwise from the filename.
"""

import json
import os
import sys

# Systems the console knows about. Folders are searched in this order.
SYSTEMS = {
    "nes": {
        "folders": ["NES", "nes", "roms/nes"],
        "exts": [".nes", ".unf", ".unif"],
    },
    "snes": {
        "folders": ["SNES", "snes", "roms/snes"],
        "exts": [".sfc", ".smc", ".fig", ".swc"],
    },
}

COVER_EXTS = [".png", ".jpg", ".jpeg", ".webp", ".gif"]
COVER_NAMES = ["cover", "box", "art", "thumb"]
OUT = "roms.json"


def web(path):
    """Repo path -> URL the browser can ask for."""
    return path.replace(os.sep, "/")


def pretty(name):
    stem = os.path.splitext(name)[0]
    for ch in "._-":
        stem = stem.replace(ch, " ")
    stem = " ".join(stem.split())
    # all-lowercase filenames read better title-cased; anything already
    # capitalised is left exactly as typed
    if stem and stem == stem.lower():
        stem = " ".join(w[:1].upper() + w[1:] for w in stem.split())
    return stem


def find_cover(folder, rom_stem):
    """A same-named image, or a generic cover.png in a per-game folder."""
    try:
        entries = os.listdir(folder)
    except OSError:
        return None
    lowered = {e.lower(): e for e in entries}
    for ext in COVER_EXTS:
        want = (rom_stem + ext).lower()
        if want in lowered:
            return web(os.path.join(folder, lowered[want]))
    for base in COVER_NAMES:
        for ext in COVER_EXTS:
            if (base + ext) in lowered:
                return web(os.path.join(folder, lowered[base + ext]))
    return None


def scan_system(cfg, root):
    found = []
    seen = set()

    for folder in cfg["folders"]:
        start = os.path.join(root, folder)
        if not os.path.isdir(start):
            continue

        for dirpath, dirnames, filenames in os.walk(start):
            dirnames[:] = [d for d in dirnames if not d.startswith(".")]
            for filename in sorted(filenames):
                if os.path.splitext(filename)[1].lower() not in cfg["exts"]:
                    continue

                full = os.path.join(dirpath, filename)
                rel = os.path.relpath(full, root)
                key = web(rel).lower()
                if key in seen:
                    continue
                seen.add(key)

                # a folder per game names the game; a loose file names itself
                in_subfolder = os.path.normpath(dirpath) != os.path.normpath(start)
                name = pretty(os.path.basename(dirpath)) if in_subfolder else pretty(filename)

                cover = find_cover(dirpath, os.path.splitext(filename)[0])
                entry = {"name": name, "file": web(rel)}
                if cover:
                    entry["cover"] = cover
                found.append(entry)

    found.sort(key=lambda e: e["name"].lower())
    return found


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
    out = {}
    total = 0

    for key, cfg in SYSTEMS.items():
        games = scan_system(cfg, root)
        out[key] = games
        total += len(games)
        print("%-5s %d game(s)" % (key.upper(), len(games)))
        for g in games:
            print("      %s  <-  %s" % (g["name"], g["file"]))

    path = os.path.join(root, OUT)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)
        f.write("\n")

    print("\nWrote %s (%d game(s) total)." % (OUT, total))
    if not total:
        print("Nothing found. Expected folders: " +
              ", ".join(f + "/" for cfg in SYSTEMS.values() for f in cfg["folders"]))


if __name__ == "__main__":
    main()
