"""One-time migration: passes every text shown to people through `tr(...)`.

    python3 scripts/l10n_rewrite.py            # dry run: writes the report
    python3 scripts/l10n_rewrite.py --write    # rewrites the Swift files

Technical strings stay as they are: SF Symbols, identifiers, keys, raw values, comparisons,
formats, URLs. The report lists what was wrapped and what looked like words but was left alone.
"""
import glob
import json
import re
import sys

sys.path.insert(0, "scripts")
from l10n_scan import scan, line_of  # noqa: E402

ROOTS = ("App", "Shared", "Widgets")
SKIP_FILES = {"Shared/Support/Localization.swift", "App/Core/ScreenshotMode.swift.disabled"}

# Text immediately before the literal (same line) that marks a technical string.
SKIP_BEFORE = [
    r"(?:systemImage|systemName|symbol|identifier|\bid|icon|Hex|hex):[^,]*\?[^,]*$", r"dropFirst\(\s*$", r"dropLast\(\s*$",
    r"systemName:\s*$", r"systemImage:\s*$", r"symbol:\s*$", r"symbols?:\s*\[?\s*$", r"Image\(\s*$",
    r"accessibilityIdentifier\(\s*$", r"identifier:\s*$", r"\bid:\s*$", r"ID:\s*$", r"forKey:\s*$", r"\bkey:\s*$",
    r"named:\s*$", r"[hH]ex:\s*$", r"URL\(string:\s*$", r"\.custom\(\s*$", r"rawValue:\s*$", r"fontName:\s*$",
    r"print\(\s*$", r"fatalError\(\s*$", r"precondition\w*\(.*$", r"assert\w*\(.*$", r"Logger\(.*$",
    r"dateFormat\s*=\s*$", r"template:\s*$", r"NSPredicate\(format:\s*$", r"\.value\(\s*$", r"[=!]=\s*$",
    r"\bcase\s+(\"[^\"]*\"\s*,\s*)*$", r"hasPrefix\(\s*$", r"hasSuffix\(\s*$", r"\.contains\(\s*$",
    r"replacingOccurrences\(of:\s*$", r"separatedBy:\s*$", r"Component\(\s*$", r"forResource:\s*$",
    r"withExtension:\s*$", r"ofType:\s*$", r"suiteName:\s*$", r"keywords:\s*\[[^\]]*$", r"\baka:\s*\[[^\]]*$", r"\.log\(", r"\blogger\b", r"os_log", r"setValue\(", r"@AppStorage\(\s*$",
    r"Notification\.Name\(\s*$", r"label:\s*\"?$(?<=DispatchQueue\(label:)", r"verbatim:\s*$", r"\.tag\(\s*$",
    r"snapshot\(\s*$", r"launchArguments", r"LocalizedStringResource", r"IntentDescription\(", r"DisplayRepresentation",
    r"\bkind:\s*$", r"\bscheme\b", r"\.font\(", r"appending\(path:\s*$", r"Color\(\s*$", r"UIImage\(named:\s*$",
    r"activityType", r"\bstyle:\s*$", r"@Parameter", r"caseDisplayRepresentations", r"\bselector\b",
    r"\bpreset\(\s*$", r"\bpalette\(\s*$", r"theme\(\s*$", r"\.decode\(", r"\bslug\b", r"\bcurrency:\s*$",
    r"currencyCode\s*=\s*$", r"Locale\(identifier:\s*$", r"TimeZone\(identifier:\s*$", r"\bformat:\s*$",
    r"String\(format:\s*$", r"\bregex\b", r"Regex", r"exerciseID:\s*$", r"demo\(for:\s*$", r"\bcode:\s*$",
    r"\bicon:\s*$", r"\bemoji:\s*$", r"barcode", r"\.quotes\b|quotes\[", r"\bsymbolName", r"\bimageName", r"\bcolor:\s*$",
]
SKIP_BEFORE_RE = re.compile("|".join(f"(?:{p})" for p in SKIP_BEFORE))

# Whole lines that hold only technical strings.
SKIP_LINE_RE = re.compile(r"^\s*(case\s+\w+\s*=\s*\"|@(?!unknown)|#|static\s+let\s+\w*(?:Key|ID|Identifier|Kind|Suffix|Prefix)\b|let\s+\w*(?:Key|ID)\s*=)")

# Properties whose value is shown (a single lowercase word inside them is a word, not an identifier).
DISPLAY_NAMES = re.compile(r"^(title|titles|name|names|label|labels|subtitle|detail|details|summary|unit|units|unitLabel|shortTitle|"
                           r"caption|message|hint|placeholder|prompt|text|explanation|headline|footnote|advice|tip|tips|"
                           r"short|shortName|plural|singular|period|periodTitle|statusText|status|verb|noun|word|words|"
                           r"heading|line|lines|question|answer|reason|note|description|cue|cues|instructions|steps|mistakes|"
                           r"\w*Title|\w*Label|\w*Text|\w*Name|\w*Unit|\w*Message)$")
TECH_NAMES = re.compile(r"(symbol|icon|systemImage|image|id|key|rawValue|identifier|hex|color|url|kind|slug|code|font|format|template|emoji)", re.I)

WORD = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿŒœ]{2,}")
ACCENT = re.compile(r"[À-ÖØ-öø-ÿŒœ«»’…]")


def looks_like_words(lit):
    text = "".join(p[1] for p in lit.parts if p[0] == "text")
    if not WORD.search(text):
        return False
    if "://" in text or re.search(r"\.(json|png|jpg|txt|plist|caf|mp4|gif)\b", text) or "@" in text and "." in text:
        return False
    if re.fullmatch(r"[\w.\-/:%]+", text) and ("." in text or "_" in text or "/" in text) and not ACCENT.search(text):
        return False  # symbols, file names, dotted identifiers
    if re.search(r"[a-z][A-Z]", text) and " " not in text:
        return False  # camelCase identifiers
    if " " in text.strip() and len(WORD.findall(text)) >= 1:
        return True
    if lit.has_interpolation and re.search(r"[a-zà-ÿ]{2,} |\s[a-zà-ÿ]{1,}", text):
        return True  # "\(n) restants", "marge \(x)"
    if re.search(r"[a-zà-ÿ]['’][a-zà-ÿ]", text):
        return True  # "aujourd'hui"
    if ACCENT.search(text):
        return True
    if re.fullmatch(r"[A-ZÀ-Ý][a-zà-ÿ'’\-]+[.!?…]?", text.strip()):
        return True  # one capitalized word: "Calories", "Repos"
    return None  # a single lowercase word: depends on where it is


def scope_names(source):
    """For every offset, the innermost declared name (var/func/let) the code is in."""
    names = []
    stack = []  # (name, depth when declared)
    depth = 0
    pending = None
    result = [None] * (len(source) + 1)
    i = 0
    decl = re.compile(r"\b(?:var|func|let|case)\s+`?(\w+)")
    lines = source.split("\n")
    offset = 0
    for line in lines:
        m = None
        for m in decl.finditer(line):
            pass
        if m and m.group(0).split()[0] in ("var", "func"):
            pending = m.group(1)
        for j, c in enumerate(line):
            if c == "{":
                depth += 1
                if pending:
                    stack.append((pending, depth))
                    pending = None
            elif c == "}":
                while stack and stack[-1][1] >= depth:
                    stack.pop()
                depth -= 1
            result[offset + j] = stack[-1][0] if stack else None
        result[offset + len(line)] = stack[-1][0] if stack else None
        # A computed property written on one line ("var title: String { … }") was handled above;
        # a stored one ("let title = …") is the name for its own line only.
        offset += len(line) + 1
        if pending and "{" not in line:
            pending = pending if line.rstrip().endswith(("->", ",", "(")) or "{" in line else pending
    return result, lines


SWIFTUI_CALLS = {"Text", "Button", "Label", "Toggle", "TextField", "SecureField", "Picker", "Stepper", "DatePicker", "Section",
                 "navigationTitle", "alert", "confirmationDialog", "accessibilityLabel", "accessibilityHint", "accessibilityValue",
                 "ContentUnavailableView", "Link", "Menu", "LabeledContent", "ProgressView", "plural", "help", "badge"}
TECH_CALLS = {"shown", "isHidden", "design", "preset", "palette", "theme", "id", "openEditor", "hex", "Color", "Image", "setValue",
              "URLQueryItem", "tag", "font", "custom", "value", "small", "medium", "large", "circular", "rectangular", "f", "x", "make"}
TECH = set()      # words seen as technical strings anywhere (filled by main)
VOCAB = set()     # words seen in French sentences (filled by main)


def enclosing_call(before):
    depth = 0
    for i in range(len(before) - 1, -1, -1):
        c = before[i]
        if c in ")]":
            depth += 1
        elif c in "([":
            if depth == 0:
                if c == "[":
                    return "["
                m = re.search(r"([A-Za-z_][\w]*)\s*$", before[:i])
                return m.group(1) if m else "("
            depth -= 1
    return None


def decide(source, lit, scopes, line_text, before, after, line_decl):
    kind = looks_like_words(lit)
    if lit.kind != "plain":
        return ("skip", "raw/multiline") if kind else ("no", "")
    if kind is False:
        return ("no", "")
    if any(p[0] == "code" and re.match(r"\s*(Image|Text)\(", p[1]) for p in lit.parts) or "**" in lit.text:
        return ("skip", "manual")
    if re.search(r"\btr\(\s*$", before):
        return ("no", "already")
    if SKIP_LINE_RE.search(line_text):
        return ("skip", "line") if kind else ("no", "")
    switch_case = re.match(r"^\s*(?:case\s+\.\w+(?:\([^)]*\))?(?:\s*,\s*\.\w+(?:\([^)]*\))?)*|default|@unknown default):\s*(?:return\s+)?$", before)
    if not switch_case and SKIP_BEFORE_RE.search(before) and not (kind and re.search(r"[=!]=\s*$", before)):
        return ("skip", "before:" + SKIP_BEFORE_RE.search(before).group(0)[:30]) if kind else ("no", "")
    if after.startswith(":") and not re.search(r"\?\s*$", before) and not kind:
        return ("no", "")  # a dictionary key ("key": value); a ternary is written "a" : "b"
    if re.match(r"\s*\.(?:rawValue|hasPrefix|count\b)", after):
        return ("skip", "compare") if kind else ("no", "")
    if kind:
        return ("wrap", "")
    # A single lowercase word.
    scope = scopes[lit.start] or ""
    word = lit.text
    call = enclosing_call(before)
    if re.match(r'^\s*"[\w-]+":\s*\[', line_text):
        return ("no", "")  # search aliases of a food
    if call in TECH_CALLS:
        return ("no", "")
    if call in SWIFTUI_CALLS:
        return ("wrap", "word")
    if re.search(r"\b(?:unit|singular|plural|title|label|detail|subtitle|caption|text|message|word|period|footnote|value|name)\s*[:=][^,;]*$", before) and word not in TECH:
        return ("wrap", "word")
    ternary = re.search(r'\?\s*$', before) and re.match(r'\s*:\s*"([^"]*)"', after) or re.search(r'"([^"]*)"\s*:\s*$', before) and re.search(r'\?\s*"[^"]*"\s*:\s*$', before)
    if ternary:
        other = ternary.group(1) if hasattr(ternary, "group") and ternary.lastindex else ""
        if (word in VOCAB and word not in TECH) or (other in VOCAB and other not in TECH):
            return ("wrap", "word")
    if line_decl and DISPLAY_NAMES.match(line_decl):
        return ("wrap", "word")
    if DISPLAY_NAMES.match(scope) and not TECH_NAMES.search(scope):
        return ("wrap", "word")
    return ("no", "word?")


def process(path, write):
    source = open(path, encoding="utf8").read()
    literals = scan(source)
    scopes, lines = scope_names(source)
    edits = []
    report = []
    for lit in literals:
        ln = line_of(source, lit.start)
        line_text = lines[ln - 1]
        line_start = source.rfind("\n", 0, lit.start) + 1
        before = source[line_start:lit.start]
        after = source[lit.end:lit.end + 40]
        m = re.search(r"\b(?:let|var)\s+(\w+)\s*(?::[^=]*)?=", before)
        line_decl = m.group(1) if m else None
        verdict, reason = decide(source, lit, scopes, line_text, before, after, line_decl)
        if verdict == "wrap":
            edits.append((lit.start, lit.end))
        if verdict != "no" or reason == "word?":
            report.append({"file": path, "line": ln, "verdict": verdict, "reason": reason, "text": lit.text,
                           "key": lit.key, "scope": scopes[lit.start], "code": line_text.strip()[:160]})
    if write and edits:
        out = source
        for start, end in sorted(edits, reverse=True):
            out = out[:start] + "tr(" + out[start:end] + ")" + out[end:]
        open(path, "w", encoding="utf8").write(out)
    return report


def main():
    write = "--write" in sys.argv
    files = sorted(f for root in ROOTS for f in glob.glob(f"{root}/**/*.swift", recursive=True) if f not in SKIP_FILES)
    # First pass: the words of French sentences, and the strings used as identifiers or symbols.
    tech_re = re.compile(r'(?:systemName|systemImage|symbol|id|identifier|rawValue|Image|named|kind|section|forKey):\s*$|Image\(\s*$|^\s*case\s+\.\w+(?:,\s*\.\w+)*:\s*$')
    for f in files:
        source = open(f, encoding="utf8").read()
        for lit in scan(source):
            if lit.kind != "plain":
                continue
            text = lit.text
            line_start = source.rfind("\n", 0, lit.start) + 1
            before = source[line_start:lit.start]
            if looks_like_words(lit) and " " in text:
                VOCAB.update(w.lower() for w in WORD.findall(text))
            if re.fullmatch(r"[a-z][\w.\-]*", text) and (tech_re.search(before) or "." in text or re.search(r"\.\w+:\s*\"[a-z.]+\"\s*$", source[line_start:lit.end])):
                if not re.search(r"(title|name|label|unit|text|caption)", before[-30:]):
                    TECH.add(text)
    report = []
    for f in files:
        report += process(f, write)
    out = sys.argv[sys.argv.index("--report") + 1] if "--report" in sys.argv else "l10n-report.json"
    json.dump(report, open(out, "w"), ensure_ascii=False, indent=1)
    from collections import Counter
    print(Counter((r["verdict"], r["reason"].split(":")[0]) for r in report))


if __name__ == "__main__":
    main()
