"""Swift string-literal scanner shared by the localization scripts.

It walks a Swift source file, skipping comments, and yields every string literal (nested ones inside
interpolations included) with its position, its raw text and the key `tr(...)` looks up at run time.
"""
import re

ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", '"': '"', "'": "'", "\\": "\\"}


class Literal:
    def __init__(self, start, end, raw, parts, depth, kind="plain"):
        self.start = start          # index of the opening quote
        self.end = end              # index just after the closing quote
        self.raw = raw              # text between the quotes, as written
        self.parts = parts          # list of ("text", unescaped) / ("code", source, [nested literals])
        self.depth = depth          # 0 for a literal in code, 1+ inside an interpolation
        self.kind = kind            # plain / multiline / raw

    @property
    def has_interpolation(self):
        return any(p[0] == "code" for p in self.parts)

    @property
    def text(self):
        """The literal with interpolations shown as \\(...)."""
        return "".join(p[1] if p[0] == "text" else "\\(" + p[1] + ")" for p in self.parts)

    @property
    def key(self):
        """The key LocalizedText builds at run time."""
        if not self.has_interpolation:
            return "".join(p[1] for p in self.parts)
        out = []
        for p in self.parts:
            out.append(p[1].replace("%", "%%") if p[0] == "text" else "%@")
        return "".join(out)

    @property
    def placeholder_count(self):
        return sum(1 for p in self.parts if p[0] == "code")


def _unescape(source, i):
    """Reads one escape starting after the backslash; returns (text, next index)."""
    c = source[i]
    if c == "u" and i + 1 < len(source) and source[i + 1] == "{":
        close = source.index("}", i)
        return chr(int(source[i + 2:close], 16)), close + 1
    return ESCAPES.get(c, c), i + 1


def scan(source):
    """All literals of a file, outermost first, nested ones after their parent."""
    found = []
    _scan_code(source, 0, len(source), 0, found, stop_at_paren=False)
    return found


def _scan_code(source, i, limit, depth, found, stop_at_paren):
    """Scans code from i; returns the index after the closing paren when stop_at_paren."""
    parens = 0
    while i < limit:
        c = source[i]
        if source.startswith("//", i):
            i = source.find("\n", i)
            if i == -1:
                return limit
            continue
        if source.startswith("/*", i):
            end = source.find("*/", i + 2)
            i = limit if end == -1 else end + 2
            continue
        if c == "#" and re.match(r'#+"', source[i:]):
            hashes = re.match(r'(#+)"', source[i:]).group(1)
            multi = source.startswith('"""', i + len(hashes))
            closing = ('"""' if multi else '"') + hashes
            end = source.find(closing, i + len(hashes) + (3 if multi else 1))
            found.append(Literal(i, end + len(closing), source[i:end + len(closing)], [], depth, "raw"))
            i = end + len(closing)
            continue
        if source.startswith('"""', i):
            end = source.find('"""', i + 3)
            found.append(Literal(i, end + 3, source[i + 3:end], [("text", source[i + 3:end])], depth, "multiline"))
            i = end + 3
            continue
        if c == '"':
            i = _scan_string(source, i, depth, found)
            continue
        if stop_at_paren:
            if c == "(":
                parens += 1
            elif c == ")":
                if parens == 0:
                    return i + 1
                parens -= 1
        i += 1
    return i


def _scan_string(source, start, depth, found):
    parts = []
    text = []
    nested = []
    i = start + 1
    literal = Literal(start, None, None, parts, depth)
    found.append(literal)
    while True:
        c = source[i]
        if c == "\\":
            if source[i + 1] == "(":
                if text:
                    parts.append(("text", "".join(text)))
                    text = []
                code_start = i + 2
                before = len(found)
                end = _scan_code(source, code_start, len(source), depth + 1, found, stop_at_paren=True)
                parts.append(("code", source[code_start:end - 1], found[before:]))
                i = end
                continue
            value, i = _unescape(source, i + 1)
            text.append(value)
            continue
        if c == '"':
            break
        if c == "\n":
            raise ValueError(f"Unterminated string at {start}")
        text.append(c)
        i += 1
    if text or not parts:
        parts.append(("text", "".join(text)))
    literal.end = i + 1
    literal.raw = source[start + 1:i]
    return i + 1


def line_of(source, index):
    return source.count("\n", 0, index) + 1
