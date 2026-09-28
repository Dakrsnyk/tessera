#!/usr/bin/env python3
"""Cheap static checks for mistakes the CI compiler would otherwise catch late (or never).

1. Memberwise initializers of the project's structs: labels in declaration order, required ones present.
2. Every widget kind is described in KindCatalog, and each V2 kind belongs to exactly one WidgetGroup.
3. `switch kind` blocks in DataNeeds cover every kind.
4. Release safety: the DEBUG Premium unlock is only referenced inside `#if DEBUG`.

Usage: python3 scripts/check_swift.py  (exit code 1 when something is wrong)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = ["App", "Shared", "Widgets", "Tests"]
problems = []


def swift_files():
    for folder in SOURCES:
        for base, _, files in os.walk(os.path.join(ROOT, folder)):
            for name in files:
                if name.endswith(".swift"):
                    yield os.path.join(base, name)


FILES = {path: open(path, encoding="utf-8").read() for path in swift_files()}


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


# ---------------------------------------------------------------- 1. memberwise inits

def block_after(text, start):
    """Returns the text inside the braces that open at or after `start`."""
    open_index = text.index("{", start)
    depth = 0
    for index in range(open_index, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[open_index + 1:index]
    return ""


def stored_properties(body):
    """Top-level stored properties of a struct body: (name, has_default)."""
    props = []
    depth = 0
    line_start = 0
    for index, char in enumerate(body + "\n"):
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        elif char == "\n":
            line = body[line_start:index]
            line_start = index + 1
            if depth != 0:
                continue
            stripped = line.strip()
            match = re.match(r"^((?:@\w+(?:\([^)]*\))?\s+)*)(?:(?:private|fileprivate|public|internal)(?:\(set\))?\s+)*(var|let)\s+(\w+)\s*(:\s*([^={]+))?(=.*)?$", stripped)
            if not match or stripped.startswith("static") or " static " in stripped:
                continue
            attrs, kind, name, _, type_text, default = match.groups()
            if re.search(r"@(Environment|EnvironmentObject|FocusState|Namespace|ScaledMetric|AppStorage|Query)\b", attrs or ""):
                continue
            if "{" in stripped and "=" not in stripped:
                continue  # computed property
            type_text = (type_text or "").strip()
            has_default = default is not None or (kind == "var" and type_text.endswith("?")) or "@State" in (attrs or "")
            if kind == "let" and default is not None:
                continue  # not part of the memberwise init
            props.append((name, has_default, "->" in type_text))
    return props


def struct_definitions():
    result = {}
    custom_init = set()
    for path, text in FILES.items():
        clean = strip_comments(text)
        for match in re.finditer(r"\bstruct\s+(\w+)\s*(?::[^{]*)?\{", clean):
            name = match.group(1)
            body = block_after(clean, match.start())
            # Explicit inits remove the memberwise one (unless declared in an extension).
            top = re.sub(r"\{[^{}]*\}", "", body)
            has_init = re.search(r"^\s*(?:public\s+)?init\s*\(", body, flags=re.M) is not None
            props = stored_properties(body)
            if name in result:
                continue
            result[name] = props
            if has_init:
                custom_init.add(name)
    return result, custom_init


def split_arguments(text):
    args, depth, current, quote = [], 0, "", False
    for index, char in enumerate(text):
        if char == '"' and (index == 0 or text[index - 1] != "\\"):
            quote = not quote
        if not quote:
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth -= 1
            elif char == "," and depth == 0:
                args.append(current)
                current = ""
                continue
        current += char
    if current.strip():
        args.append(current)
    return args


def call_arguments(text, open_index):
    depth, quote = 0, False
    for index in range(open_index, len(text)):
        char = text[index]
        if char == '"' and text[index - 1] != "\\":
            quote = not quote
        if quote:
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return text[open_index + 1:index]
    return None


def check_memberwise():
    structs, custom = struct_definitions()
    checked = 0
    for path, text in FILES.items():
        clean = strip_comments(text)
        for name, props in structs.items():
            if name in custom or not props:
                continue
            for match in re.finditer(r"(?<![\w.])" + name + r"\(", clean):
                before = clean[max(0, match.start() - 12):match.start()]
                if re.search(r"(struct|enum|func|extension|case)\s*$", before):
                    continue
                inner = call_arguments(clean, match.end() - 1)
                if inner is None or not inner.strip():
                    continue
                labels = []
                for arg in split_arguments(inner):
                    label = re.match(r"\s*(\w+)\s*:(?!:)", arg)
                    if not label:
                        labels = None
                        break
                    labels.append(label.group(1))
                if labels is None:
                    continue  # positional call: not a memberwise init
                names = [p[0] for p in props]
                close = match.end() - 1 + len(inner) + 2
                trailing = clean[close:close + 3].strip().startswith("{")
                if any(label not in names for label in labels):
                    continue  # another initializer (from an extension or a protocol)
                checked += 1
                positions = [names.index(label) for label in labels]
                line = clean[:match.start()].count("\n") + 1
                where = f"{os.path.relpath(path, ROOT)}:{line}"
                if positions != sorted(positions):
                    problems.append(f"{where}: {name}(...) labels out of order: {labels} (declared {names})")
                missing = [p for p, has_default, is_closure in props if not has_default and p not in labels and not (trailing and is_closure)]
                if missing:
                    problems.append(f"{where}: {name}(...) missing {missing}")
    return checked


# ---------------------------------------------------------------- 2-3. kinds

def enum_cases(text, enum_name):
    match = re.search(r"enum\s+" + enum_name + r"\b[^{]*\{", text)
    body = block_after(text, match.start())
    cases = []
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("case ") and "(" not in line.split("//")[0]:
            cases += [c.strip() for c in line[5:].split("//")[0].split(",") if c.strip()]
        if line.startswith("var ") or line.startswith("static ") or line.startswith("func "):
            break
    return cases


def check_kinds():
    kind_text = strip_comments(FILES[os.path.join(ROOT, "Shared/Model/WidgetKind.swift")])
    kinds = enum_cases(kind_text, "WidgetKind")
    catalog = strip_comments(FILES[os.path.join(ROOT, "Shared/Model/KindCatalog.swift")])
    described = re.findall(r"KindInfo\(kind:\s*\.(\w+)", catalog)
    for kind in kinds:
        if described.count(kind) != 1:
            problems.append(f"KindCatalog describes .{kind} {described.count(kind)} times")
    original = ["clock", "calendar", "worldClock", "progress", "countdown", "yearDots", "tasks", "habits", "focus", "upNext", "note", "weather", "crypto", "moneyFlow", "hydration"]
    group_path = os.path.join(ROOT, "Shared/Model/WidgetGroup.swift")
    if group_path in FILES:
        groups = strip_comments(FILES[group_path])
        body = groups[groups.index("var kinds: [WidgetKind]"):groups.index("var flagship")]
        grouped = re.findall(r"\.(\w+)", body)
        for kind in kinds:
            if kind in original:
                continue
            if grouped.count(kind) != 1:
                problems.append(f"WidgetGroup lists .{kind} {grouped.count(kind)} times")
    needs_path = os.path.join(ROOT, "Shared/Data/DomainData.swift")
    if needs_path in FILES:
        text = strip_comments(FILES[needs_path])
        body = text[text.index("static func needs(for kind"):text.index("extension PayloadLoader")]
        covered = re.findall(r"\.(\w+)", " ".join(line for line in body.splitlines() if line.strip().startswith("case ")))
        for kind in kinds:
            if kind not in covered:
                problems.append(f"DataNeeds.needs does not handle .{kind}")
    return len(kinds)


# ---------------------------------------------------------------- 4. release safety

def check_release_safety():
    guarded = ["DebugPremium", "isDebugPremiumOn", "setDebugPremium", "ScreenshotMode", "WidgetGalleryView", "MarketingView"]
    for path, text in FILES.items():
        depth_stack = []
        for number, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#if"):
                depth_stack.append("DEBUG" in stripped and "!" not in stripped)
                continue
            if stripped.startswith("#else"):
                if depth_stack:
                    depth_stack[-1] = not depth_stack[-1]
                continue
            if stripped.startswith("#endif"):
                if depth_stack:
                    depth_stack.pop()
                continue
            code = stripped.split("//")[0]
            for name in guarded:
                if re.search(r"\b" + name + r"\b", code) and not any(depth_stack):
                    problems.append(f"{os.path.relpath(path, ROOT)}:{number}: {name} used outside #if DEBUG")


checked = check_memberwise()
kinds = check_kinds()
check_release_safety()
if problems:
    print("\n".join(problems))
    print(f"\n{len(problems)} problem(s)")
    sys.exit(1)
print(f"OK: {checked} memberwise calls checked, {kinds} widget kinds, Release safety verified")
