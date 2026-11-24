"""Ardane's extended exercise catalogue, from free-exercise-db (https://github.com/yuhonas/free-exercise-db, commit
f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5, The Unlicense: public domain, any use, commercial included; copy of the licence in
scripts/exercises/source/LICENSE-free-exercise-db.md). The 163 exercises written in Shared/Domains/ExerciseLibrary.swift
stay as they are; every other exercise of the dataset joins them through Shared/Resources/ExerciseCatalog.json.

    python3 scripts/exercises/build_catalog.py prepare   # scripts/exercises/work/: existing.json + chunk_NN.json to translate
    python3 scripts/exercises/build_catalog.py build     # Shared/Resources/ExerciseCatalog.json from scripts/exercises/translations/NN.json

A translation file (one per chunk, written by hand or by an agent) maps each source id to
    {"dup": "<id of a built-in exercise>"}                            the same exercise as a built-in one (its names become aliases), or
    {"fr": …, "en": …, "es": …, "de": …, "it": …, "pt-BR": …, "ja": …, "aliases": [...], "pattern": "<MovementPattern>"}
The muscles, the equipment, the type and the level come from the dataset (mapped below), never from the translation.
"""
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "scripts", "exercises", "source", "free-exercise-db.json")
WORK = os.path.join(ROOT, "scripts", "exercises", "work")
TRANSLATIONS = os.path.join(ROOT, "scripts", "exercises", "translations")
LIBRARY = os.path.join(ROOT, "Shared", "Domains", "ExerciseLibrary.swift")
OUT = os.path.join(ROOT, "Shared", "Resources", "ExerciseCatalog.json")
CHUNK = 110
LANGS = ["fr", "en", "es", "de", "it", "pt-BR", "ja"]

PATTERNS = """benchPress pushUp dip verticalPush horizontalPull verticalPull seatedRow pullover squat hinge lunge legPress
legExtension legCurl bridge legKickback calfRaise curl tricepsExtension overheadExtension lyingExtension lateralRaise
frontRaise fly uprightRow shrug crunch plank legRaise rotation superman mountainClimber carry run cycle rowing jump
armCircles stretchFold stretchStand generic""".split()

MUSCLES = {
    "abdominals": "abs", "abductors": "glutes", "adductors": "quads", "biceps": "biceps", "calves": "calves",
    "chest": "chest", "forearms": "forearms", "glutes": "glutes", "hamstrings": "hamstrings", "lats": "back",
    "lower back": "lowerBack", "middle back": "back", "neck": "traps", "quadriceps": "quads", "shoulders": "shoulders",
    "traps": "traps", "triceps": "triceps",
}
EQUIPMENT = {
    "barbell": "barbell", "dumbbell": "dumbbells", "body only": "bodyweight", None: "bodyweight", "cable": "cable",
    "machine": "machine", "kettlebells": "kettlebell", "bands": "band", "e-z curl bar": "barbell",
    "medicine ball": "other", "exercise ball": "other", "foam roll": "other", "other": "other",
}
TYPES = {
    "strength": "strength", "powerlifting": "strength", "olympic weightlifting": "strength", "strongman": "strength",
    "stretching": "stretching", "plyometrics": "cardio", "cardio": "cardio",
}
LEVELS = {"beginner": "beginner", "intermediate": "intermediate", "expert": "advanced"}


def catalog_id(source_id):
    """Stable: saved in the sets (`SetLog.exerciseID`). « 3_4_Sit-Up » -> « x-3-4-sit-up »."""
    return "x-" + re.sub(r"[^a-z0-9]+", "-", source_id.lower()).strip("-")


def unique(items):
    out = []
    for item in items:
        if item not in out:
            out.append(item)
    return out


def equipment(ex):
    tools = [EQUIPMENT[ex.get("equipment")]]
    name = ex["name"].lower()
    if "smith" in name or "machine" in name or "lever" in name or "sled" in name:
        tools = ["machine"] + [t for t in tools if t not in ("other", "bodyweight")]
    if "bench" in name:
        tools.append("bench")
    if re.search(r"pull-?up|chin-?up|hanging", name):
        tools.append("pullUpBar")
    return unique(tools)


def muscles(names):
    return unique([MUSCLES[m] for m in names if m in MUSCLES])


def existing():
    """The built-in exercises: id, French name, aliases and movement, read from the Swift source."""
    text = open(LIBRARY, encoding="utf-8").read()
    out = []
    for block in re.split(r"\n\s*x\(", text)[1:]:
        m = re.match(r'"([^"]+)",\s*tr\("([^"]+)"\),\s*\[([^\]]*)\],\s*\[([^\]]*)\],\s*\[([^\]]*)\]', block)
        if not m:
            continue
        aka = re.search(r"aka:\s*\[([^\]]*)\]", block.split("\n        x(")[0])
        pattern = re.search(r"\.(\w+),\s*(?:\n\s*)?(?:aka:|cues:|\)\s*,?\s*$)", block)
        out.append({"id": m.group(1), "name": m.group(2),
                    "primary": re.findall(r"\.(\w+)", m.group(3)), "equipment": re.findall(r"\.(\w+)", m.group(5)),
                    "aliases": re.findall(r'"([^"]+)"', aka.group(1)) if aka else [],
                    "pattern": pattern.group(1) if pattern else None})
    return out


def demo_source(entry, built_in):
    """The built-in exercise whose hand-made demonstration (scripts/demos) the new one shows: same movement first,
    then the most equipment and main muscles in common; without the same movement, the closest by muscles and tools."""
    def score(b):
        return (b["pattern"] == entry["m"], len(set(b["equipment"]) & set(entry["e"])),
                len(set(b["primary"]) & set(entry["p"])), -len(b["equipment"]))
    return max(built_in, key=score)["id"]


def prepare():
    data = json.load(open(SOURCE, encoding="utf-8"))
    os.makedirs(WORK, exist_ok=True)
    built_in = existing()
    json.dump(built_in, open(os.path.join(WORK, "existing.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    rows = [{"source": ex["id"], "name": ex["name"], "category": ex["category"], "equipment": ex.get("equipment"),
             "force": ex.get("force"), "mechanic": ex.get("mechanic"), "primary": ex["primaryMuscles"],
             "secondary": ex["secondaryMuscles"], "howTo": (ex.get("instructions") or [""])[0][:220]} for ex in data]
    for n in range(0, len(rows), CHUNK):
        path = os.path.join(WORK, f"chunk_{n // CHUNK + 1:02d}.json")
        json.dump(rows[n:n + CHUNK], open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{len(built_in)} built-in exercises, {len(rows)} to translate in {(len(rows) + CHUNK - 1) // CHUNK} chunks -> {WORK}")


def build():
    data = {ex["id"]: ex for ex in json.load(open(SOURCE, encoding="utf-8"))}
    built_in_list = existing()
    built_in = {ex["id"] for ex in built_in_list}
    translated = {}
    for name in sorted(os.listdir(TRANSLATIONS)):
        if name.endswith(".json"):
            translated.update(json.load(open(os.path.join(TRANSLATIONS, name), encoding="utf-8")))
    missing = [k for k in data if k not in translated]
    if missing:
        sys.exit(f"{len(missing)} exercises without a translation, e.g. {missing[:5]}")
    exercises, extra, problems = [], {}, []
    for source_id, ex in data.items():
        t = translated[source_id]
        if t.get("dup"):
            if t["dup"] not in built_in:
                problems.append(f"{source_id}: unknown built-in {t['dup']}")
                continue
            extra.setdefault(t["dup"], []).append(ex["name"])
            continue
        names = {lang: (t.get(lang) or "").strip() for lang in LANGS}
        if not all(names.values()):
            problems.append(f"{source_id}: missing name {[k for k, v in names.items() if not v]}")
            continue
        if t.get("pattern") not in PATTERNS:
            problems.append(f"{source_id}: pattern {t.get('pattern')!r}")
            continue
        primary = muscles(ex["primaryMuscles"]) or ["fullBody"]
        secondary = [m for m in muscles(ex["secondaryMuscles"]) if m not in primary]
        kind = TYPES[ex["category"]]
        if kind == "strength" and t["pattern"] in ("stretchFold", "stretchStand"):
            kind = "stretching"
        aliases = unique([a.strip() for a in [ex["name"]] + list(t.get("aliases") or []) if a and a.strip()])
        entry = {"id": catalog_id(source_id), "n": names, "a": aliases, "p": primary, "s": secondary,
                 "e": equipment(ex), "t": kind, "d": LEVELS[ex["level"]], "m": t["pattern"]}
        entry["demo"] = demo_source(entry, built_in_list)
        exercises.append(entry)
    if problems:
        sys.exit("\n".join(problems[:40]) + f"\n{len(problems)} problems")
    # The built-in exercises in every language too: a set saved in French (« Curl à la poulie ») is still that exercise
    # on an iPhone in English, where its name reads « Cable curl » (seen on the CEO's iPhone, 2026-11-23).
    l10n = {lang: json.load(open(os.path.join(ROOT, "l10n", f"{lang}.json"), encoding="utf-8")) for lang in LANGS if lang != "fr"}
    for ex in built_in_list:
        names = [ex["name"]] + [l10n[lang][ex["name"]] for lang in l10n if l10n[lang].get(ex["name"])]
        extra[ex["id"]] = unique(extra.get(ex["id"], []) + names)
    # Two exercises with the same name in a language (a rare one translated alike): the later one gets its English
    # name in parentheses, so that each name in each language leads to one exercise.
    for lang in LANGS:
        seen = set()
        for e in exercises:
            key = e["n"][lang].lower()
            if key in seen:
                e["n"][lang] = f"{e['n'][lang]} ({e['n']['en']})"
            seen.add(e["n"][lang].lower())
    # An alias leads to one exercise only. A catalogue alias that is a name or alias of a built-in exercise, or a name
    # of another catalogue exercise, is dropped (the app looks in the built-in exercises first: they keep their history);
    # an alias two catalogue exercises share stays with the first one (code review, 2026-11-23).
    def key(text):
        folded = "".join(c for c in unicodedata.normalize("NFD", text.lower()) if unicodedata.category(c) != "Mn")
        return " ".join("".join(c if c.isalnum() else " " for c in folded).split())
    taken = {key(n) for ex in built_in_list for n in [ex["name"]] + ex["aliases"] + extra.get(ex["id"], [])}
    names_of = {}
    for e in exercises:
        for n in e["n"].values():
            names_of.setdefault(key(n), e["id"])
    dropped = 0
    for e in exercises:
        kept = []
        for alias in e["a"]:
            k = key(alias)
            if k in taken or names_of.get(k, e["id"]) != e["id"]:
                dropped += 1
                continue
            taken.add(k)
            kept.append(alias)
        e["a"] = kept
    print(f"{dropped} ambiguous aliases dropped")
    ids = [e["id"] for e in exercises]
    assert len(ids) == len(set(ids)) and not set(ids) & built_in
    exercises.sort(key=lambda e: e["n"]["fr"].lower())
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    catalog = {"source": "free-exercise-db (The Unlicense, public domain), commit f00c92c7", "exercises": exercises,
               "extraAliases": extra}
    json.dump(catalog, open(OUT, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, separators=(",", ":"))
    print(f"{len(exercises)} new exercises, {sum(len(v) for v in extra.values())} more names (7 languages, duplicates) for {len(extra)} "
          f"built-in ones -> {OUT} ({os.path.getsize(OUT) // 1024} KB); total {len(exercises) + len(built_in)}")


if __name__ == "__main__":
    {"prepare": prepare, "build": build}[sys.argv[1]]()
