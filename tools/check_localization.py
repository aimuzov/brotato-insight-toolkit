#!/usr/bin/env python3

import collections
import json
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools/localization-source.json"
CATALOGUES = ROOT / "mods-unpacked/aimuzov-DpsCheck/localization"
TOKEN = re.compile(r"\{\d+\}|%[sdif]|\[/?[^\[\]\r\n]+\]")


def read_json(path):
    def unique_keys(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key in {path}: {key}")
            result[key] = value
        return result

    return json.loads(path.read_text(), object_pairs_hook=unique_keys)


def main():
    source = read_json(SOURCE)
    entries = source["entries"]
    expected = {entry["source"] for entry in entries}
    failures = []
    for variant in ["ru_full", "ru_short"]:
        catalogue = read_json(CATALOGUES / f"{variant}.json")
        if variant == "ru_short":
            for key, expected_text in {"STAT_LIFESTEAL": "% Кража", "LIFESTEAL": "Кража", "STAT_CRIT_CHANCE": "% Крит"}.items():
                if catalogue["by_key"].get(key) != expected_text:
                    failures.append(f"{variant}: wrong short label for {key}")
        if set(catalogue["by_source"]) != expected:
            failures.append(f"{variant}: English source coverage differs")
        for entry in entries:
            text = entry["source"]
            key = entry["key"]
            target = catalogue["by_key"].get(key, catalogue["by_source"].get(text))
            if not isinstance(target, str) or not target.strip():
                failures.append(f"{variant}: missing text for {key or text}")
                continue
            if collections.Counter(TOKEN.findall(text)) != collections.Counter(TOKEN.findall(target)):
                failures.append(f"{variant}: tokens differ for {key or text}")
            if text.startswith("%") != target.startswith("%"):
                failures.append(f"{variant}: percentage unit differs for {key or text}")
            if "<!MissingKey" in target:
                failures.append(f"{variant}: diagnostic key leaked into translation")
            if entry.get("kind") == "technical" and target != "russian":
                failures.append(f"{variant}: platform language identifier changed")
        print(f"{variant}: {len(entries)} entries, {len(expected)} English messages")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Localization checks passed for Brotato {source['game_version']}")


if __name__ == "__main__":
    main()
