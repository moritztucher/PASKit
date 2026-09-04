#!/usr/bin/env python3
"""
check-collisions.py — PASKit symbol-collision detector.

Swift resolves an unqualified name against the current module before an
imported one. If an app declares a top-level type or an extension member
with the same name as something PASKit already exports from a module the
app imports, the app's copy silently wins — even in files that `import
PASKit`. This has happened three times across three apps; this script
makes it mechanical instead of relying on documentation and review.

Usage:
    python3 check-collisions.py [ROOT ...] [options]

    ROOT            One or more directories to scan (an app target, or a
                     local package's Sources/<Target>). Default: current
                     directory.

Key options (see --help for the rest):
    --paskit PATH        PASKit checkout to extract the surface from.
    --paskit-rev REV     Revision to shallow-clone when no checkout is found.
    --allowlist PATH     Default: <git top-level of ROOT>/.paskit-collisions-allow
    --format human|github|json
    --self-check          Assert PASKit's own surface still contains the
                           sentinel symbols this script depends on (used by
                           PASKit's own CI — run from a PASKit checkout).
    --dump-surface [FILE] Print/write the extracted PASKit surface and exit.

Exit codes:
    0  clean (warnings allowed)
    1  at least one error (or --warn-only maps this to 0)
    2  usage error / PASKit root not found / malformed allowlist /
       parser self-check failed

See CLAUDE-INTEGRATION.md "Collision check" in the PASKit repo for the
full contract this script implements.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field, asdict
from typing import Optional

# --------------------------------------------------------------------------
# Source stripping — comments and string literals blanked, newlines kept so
# line numbers stay accurate. Single pass, character by character.
# --------------------------------------------------------------------------


def strip_source(text: str) -> str:
    out = []
    i = 0
    n = len(text)
    while i < n:
        # Block comment /* ... */ (not nesting-aware — accepted limitation).
        if text[i] == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            end = n if j == -1 else j + 2
            segment = text[i:end]
            out.append("".join("\n" if ch == "\n" else " " for ch in segment))
            i = end
            continue
        # Triple-quoted multi-line string """ ... """.
        if text[i : i + 3] == '"""':
            j = text.find('"""', i + 3)
            end = n if j == -1 else j + 3
            segment = text[i:end]
            out.append("".join("\n" if ch == "\n" else " " for ch in segment))
            i = end
            continue
        # Line comment // ... to end of line.
        if text[i] == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            end = n if j == -1 else j
            out.append(" " * (end - i))
            i = end
            continue
        # Single-line string literal "..." (handles \" and \\ escapes).
        if text[i] == '"':
            j = i + 1
            while j < n and text[j] != "\n" and text[j] != '"':
                if text[j] == "\\" and j + 1 < n:
                    j += 2
                else:
                    j += 1
            end = min(j + 1, n)
            out.append(" " * (end - i))
            i = end
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


# --------------------------------------------------------------------------
# Declaration matching
# --------------------------------------------------------------------------

ACCESS_KEYWORDS = {"public", "open", "package", "internal", "fileprivate", "private"}
MODIFIER_KEYWORDS = (
    "static|class|final|nonisolated|mutating|override|convenience|indirect|"
    "prefix|infix|postfix|unowned|weak|lazy|dynamic|optional|required|async|throws"
)
CONTAINER_KINDS = {"struct", "class", "enum", "actor", "protocol", "extension"}
MEMBER_KINDS = {"func", "var", "let", "typealias", "init", "subscript", "case", "operator", "macro"}
ALL_KINDS = CONTAINER_KINDS | MEMBER_KINDS

DECL_RE = re.compile(
    r"^\s*"
    r"(?:@\w+(?:\([^)]*\))?\s+)*"  # attributes
    r"(?:(public|open|package|internal|fileprivate|private)\s+)?"  # access
    r"(?:(?:" + MODIFIER_KEYWORDS + r")\s+)*"  # modifiers (incl. leading 'class' before 'func')
    r"(struct|class|enum|actor|protocol|extension|func|var|let|typealias|case|operator|macro)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*|[^\sA-Za-z0-9_(.,;]+)"
)

# `init` and `subscript` have no name token of their own — `init(...)` /
# `subscript(...)` — so they need a dedicated pattern that stops right
# after the keyword instead of requiring `\s+<name>`.
INIT_SUBSCRIPT_RE = re.compile(
    r"^\s*"
    r"(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:(public|open|package|internal|fileprivate|private)\s+)?"
    r"(?:(?:" + MODIFIER_KEYWORDS + r")\s+)*"
    r"(init|subscript)\b\s*[?!]?\s*(?=[(<])"
)

IMPORT_RE = re.compile(r"^\s*(?:@_exported\s+)?import\s+(PASKit\w*)\b")


@dataclass
class Decl:
    kind: str
    name: str
    access: Optional[str]  # explicit access keyword on this line, or None
    is_static: bool
    parent_kind: Optional[str]
    parent_name: Optional[str]
    file: str
    line: int
    labels: Optional[str] = None  # 'label1:label2:' for func/subscript/init, '' for no-arg, None otherwise


@dataclass
class Frame:
    kind: str
    name: str
    access: str  # effective access of the container itself
    depth_at_open: int


def _extract_labels(lines: list[str], line_idx: int, name_end_col: int) -> Optional[str]:
    """Join lines from (line_idx, name_end_col) until parens balance, then
    parse top-level comma-separated argument labels into 'label1:label2:'
    form. Returns None if no '(' is found on the declaration line's
    immediate continuation (e.g. a `var`)."""
    # Find the first '(' after the name, allowing a generic clause <...> to
    # precede it (skip past any '<...>' first).
    text = lines[line_idx][name_end_col:]
    scan_lines = [text] + lines[line_idx + 1 : line_idx + 40]
    joined = "\n".join(scan_lines)

    idx = 0
    while idx < len(joined) and joined[idx] in " \t\n":
        idx += 1
    if idx < len(joined) and joined[idx] in "?!":  # failable init / IUO subscript marker
        idx += 1
        while idx < len(joined) and joined[idx] in " \t\n":
            idx += 1

    # Skip a generic parameter clause, e.g. <T: Comparable>.
    stripped = joined[idx:].lstrip()
    lead_ws = idx + (len(joined[idx:]) - len(stripped))
    if stripped.startswith("<"):
        depth = 0
        k = lead_ws
        while k < len(joined):
            if joined[k] == "<":
                depth += 1
            elif joined[k] == ">":
                depth -= 1
                if depth == 0:
                    k += 1
                    break
            k += 1
        idx = k
        # skip whitespace after generic clause
        while idx < len(joined) and joined[idx] in " \t\n":
            idx += 1

    if idx >= len(joined) or joined[idx] != "(":
        return None

    depth = 0
    start = idx
    end = None
    k = idx
    while k < len(joined):
        c = joined[k]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                end = k
                break
        k += 1
    if end is None:
        return None  # unbalanced within scan window — give up gracefully

    body = joined[start + 1 : end]
    if body.strip() == "":
        return ""

    # Split body on top-level commas (respecting (), [], <>). '->' is
    # skipped as a unit so a closure/function return arrow doesn't get
    # misread as a lone '>' closing an angle-bracket depth that was never
    # opened (e.g. `@escaping () async -> Bool`).
    parts = []
    depth2 = 0
    cur = []
    k = 0
    while k < len(body):
        ch = body[k]
        if ch == "-" and k + 1 < len(body) and body[k + 1] == ">":
            cur.append("->")
            k += 2
            continue
        if ch in "([<":
            depth2 += 1
        elif ch in ")]>":
            depth2 = max(0, depth2 - 1)
        if ch == "," and depth2 == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
        k += 1
    if cur:
        parts.append("".join(cur))

    labels = []
    for part in parts:
        head = part.split(":", 1)[0].strip()
        # Drop leading attributes like @escaping / inout / modifiers.
        tokens = [t for t in head.split() if not t.startswith("@") and t != "inout"]
        if not tokens:
            continue
        first = tokens[0]
        labels.append("" if first == "_" else first)
    return ":".join(labels) + (":" if labels else "")


def parse_file(path: str, repo_root: str) -> tuple[list[Decl], set[str]]:
    """Parse one Swift file. Returns (declarations, imported PASKit modules)."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        raw = f.read()
    cleaned = strip_source(raw)
    lines = cleaned.split("\n")
    raw_lines = raw.split("\n")

    imports: set[str] = set()
    for rl in raw_lines:
        m = IMPORT_RE.match(rl)
        if m:
            imports.add(m.group(1))

    rel = os.path.relpath(path, repo_root)
    decls: list[Decl] = []
    stack: list[Frame] = []
    depth = 0

    for i, line in enumerate(lines):
        m = DECL_RE.match(line)
        m_init = None if m else INIT_SUBSCRIPT_RE.match(line)
        opens = line.count("{")
        closes = line.count("}")

        kind: Optional[str] = None
        access: Optional[str] = None
        name: Optional[str] = None

        if m or m_init:
            if m:
                access, kind, name = m.group(1), m.group(2), m.group(3)
                name_end = m.end(3)
                mod_prefix_end = m.start(3)
            else:
                access, kind = m_init.group(1), m_init.group(2)
                name = kind  # init/subscript have no name token of their own
                name_end = m_init.end(2)
                mod_prefix_end = m_init.start(2)

            is_static = bool(re.search(r"\b(static|class)\s+\w", " " + line[:mod_prefix_end]))
            parent_kind = stack[-1].kind if stack else None
            parent_name = stack[-1].name if stack else None

            labels = None
            if kind in ("func", "subscript", "init"):
                labels = _extract_labels(lines, i, name_end)

            decls.append(
                Decl(
                    kind=kind,
                    name=name,
                    access=access,
                    is_static=is_static,
                    parent_kind=parent_kind,
                    parent_name=parent_name,
                    file=rel,
                    line=i + 1,
                    labels=labels,
                )
            )

        # Track scope depth for EVERY brace-opening line, not just recognized
        # container declarations — a func/init/subscript body, a computed
        # property's { get / set } block, a closure, or a plain control-flow
        # block ({ if/for/while/do/guard }) all open a scope whose contents
        # must not be attributed to the enclosing type/extension (otherwise
        # a local `let x = …` inside a method body would be misread as a
        # sibling member of that method's enclosing type).
        if opens > closes:
            new_depth = depth + (opens - closes)
            if kind in CONTAINER_KINDS:
                # Effective access of the container itself, for inheritance
                # by members declared without an explicit access keyword.
                if access:
                    eff = access
                elif stack and stack[-1].kind in ("extension", "protocol") and stack[-1].access in ("public", "open"):
                    eff = stack[-1].access
                else:
                    eff = "internal"
                stack.append(Frame(kind=kind, name=name, access=eff, depth_at_open=new_depth))
            else:
                stack.append(Frame(kind="_block", name="", access="internal", depth_at_open=new_depth))
            depth = new_depth
        else:
            depth += opens - closes
            while stack and depth < stack[-1].depth_at_open:
                stack.pop()

    return decls, imports


# --------------------------------------------------------------------------
# PASKit surface extraction
# --------------------------------------------------------------------------


@dataclass
class Symbol:
    module: str
    kind: str  # 'T' (top-level type), 'X' (extension member on external type), 'F', 'M', 'O'
    name: str
    extension_of: Optional[str]
    is_static: bool
    labels: Optional[str]
    file: str
    line: int


def _walk_swift_files(root: str, skip_dirs: tuple[str, ...] = ()) -> list[str]:
    result = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for fn in filenames:
            if fn.endswith(".swift"):
                result.append(os.path.join(dirpath, fn))
    return sorted(result)


def build_surface(paskit_root: str) -> list[Symbol]:
    sources_dir = os.path.join(paskit_root, "Sources")
    modules = sorted(
        m
        for m in os.listdir(sources_dir)
        if os.path.isdir(os.path.join(sources_dir, m)) and m != "PASKit"
    )

    per_module_decls: dict[str, list[Decl]] = {}
    for module in modules:
        files = _walk_swift_files(os.path.join(sources_dir, module))
        decls: list[Decl] = []
        for f in files:
            file_decls, _ = parse_file(f, paskit_root)
            decls.extend(file_decls)
        per_module_decls[module] = decls

    # Pass 1: collect all top-level type names (any access) across all
    # modules, needed to decide whether an extension's extended type is
    # "external" (E ∉ T) for Rule X.
    all_top_level_types: set[str] = set()
    for decls in per_module_decls.values():
        for d in decls:
            if d.kind in ("struct", "class", "enum", "actor", "protocol", "typealias") and d.parent_kind is None:
                all_top_level_types.add(d.name)

    symbols: list[Symbol] = []
    for module, decls in per_module_decls.items():
        # Need the effective access of each decl's parent container to
        # compute inheritance; re-derive using a lightweight index keyed by
        # (file, parent_kind, parent_name, line-of-open) is overkill — reuse
        # the parse-time approach by walking per file again with the stack
        # already recorded implicitly via parent chain depth 1 only.
        #
        # Since Rule sets here only care about depth-1 declarations (top
        # level types, and members directly inside a top-level extension),
        # a single lookup of "was the immediate parent an extension/protocol
        # declared public/open" suffices. We recompute that from the raw
        # decls: for each Decl whose parent is an extension/protocol, find
        # the matching container Decl (same file, same name/kind, kind in
        # CONTAINER_KINDS) to read its own access.
        container_access: dict[tuple[str, str, str], str] = {}
        for d in decls:
            if d.kind in CONTAINER_KINDS:
                key = (d.file, d.kind, d.name)
                # last one wins if duplicate extensions of same type in a file
                explicit = d.access or "internal"
                if explicit in ("public", "open"):
                    container_access[key] = explicit
                elif key not in container_access:
                    container_access[key] = explicit

        for d in decls:
            if d.parent_kind is None:
                # Top-level declaration.
                if d.kind in ("struct", "class", "enum", "actor", "protocol", "typealias"):
                    eff = d.access or "internal"
                    if eff in ("public", "open"):
                        symbols.append(
                            Symbol(module, "T", d.name, None, d.is_static, None, d.file, d.line)
                        )
                elif d.kind in ("func", "var", "let"):
                    eff = d.access or "internal"
                    if eff in ("public", "open"):
                        symbols.append(
                            Symbol(module, "F", d.name, None, d.is_static, d.labels, d.file, d.line)
                        )
                continue

            if d.parent_kind == "extension":
                parent_access = container_access.get((d.file, "extension", d.parent_name), "internal")
                eff = d.access or (parent_access if parent_access in ("public", "open") else "internal")
                if eff not in ("public", "open"):
                    continue
                if d.kind in ("func", "var", "subscript", "init"):
                    if d.parent_name in all_top_level_types:
                        # Extension of PASKit's own type — ordinary member, not X.
                        continue
                    symbols.append(
                        Symbol(module, "X", d.name, d.parent_name, d.is_static, d.labels, d.file, d.line)
                    )
                continue

            if d.kind == "operator" and d.parent_kind is None:
                symbols.append(Symbol(module, "O", d.name, None, d.is_static, None, d.file, d.line))

    # Top-level operators (declared at file scope, parent_kind None) —
    # handled above via the 'func|var|let' branch only; catch 'operator'
    # explicitly since it's not in that tuple.
    for module, decls in per_module_decls.items():
        for d in decls:
            if d.kind == "operator" and d.parent_kind is None:
                eff = d.access or "internal"
                if eff in ("public", "open"):
                    if not any(s.kind == "O" and s.name == d.name and s.file == d.file and s.line == d.line for s in symbols):
                        symbols.append(Symbol(module, "O", d.name, None, d.is_static, None, d.file, d.line))

    return symbols


def resolve_paskit_root(args) -> tuple[str, list[str]]:
    """Returns (paskit_root, notes)."""
    notes = []

    def is_paskit_checkout(p: str) -> bool:
        pkg = os.path.join(p, "Package.swift")
        if not os.path.isfile(pkg):
            return False
        try:
            with open(pkg, "r", encoding="utf-8", errors="replace") as f:
                head = f.read(500)
            return 'name: "PASKit"' in head or "name:\"PASKit\"" in head
        except OSError:
            return False

    if args.paskit:
        if not is_paskit_checkout(args.paskit):
            print(f"error: --paskit {args.paskit} is not a PASKit checkout (no Package.swift named PASKit)", file=sys.stderr)
            sys.exit(2)
        return args.paskit, notes

    env_root = os.environ.get("PASKIT_ROOT")
    if env_root:
        if not is_paskit_checkout(env_root):
            print(f"error: $PASKIT_ROOT {env_root} is not a PASKit checkout", file=sys.stderr)
            sys.exit(2)
        return env_root, notes

    # Sibling ../PASKit relative to the first ROOT's git top-level.
    first_root = args.roots[0] if args.roots else "."
    try:
        top = subprocess.run(
            ["git", "-C", first_root, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        top = os.path.abspath(first_root)

    sibling = os.path.normpath(os.path.join(top, "..", "PASKit"))
    if is_paskit_checkout(sibling):
        pinned = find_pinned_revision(args.roots)
        if pinned:
            head = subprocess.run(
                ["git", "-C", sibling, "rev-parse", "HEAD"], capture_output=True, text=True
            ).stdout.strip()
            if head and not head.startswith(pinned) and not pinned.startswith(head):
                notes.append(
                    f"note: {sibling} is at {head[:8]} but the app pins {pinned[:8]}; "
                    f"surface may differ — pass --paskit-rev to clone the pin"
                )
        else:
            notes.append(f"note: using sibling PASKit at {sibling} (no pin found to compare against)")
        return sibling, notes

    # Shallow clone at --paskit-rev (or the pinned revision) into a temp dir.
    rev = args.paskit_rev or find_pinned_revision(args.roots) or "develop"
    tmp = tempfile.mkdtemp(prefix="paskit-collisions-")
    notes.append(f"note: cloning PASKit @ {rev} into {tmp}")
    try:
        subprocess.run(
            ["git", "clone", "--quiet", "--depth", "1", "--branch", rev,
             "https://github.com/moritztucher/PASKit.git", tmp],
            check=True,
        )
    except subprocess.CalledProcessError:
        # rev may be a bare SHA, not a branch/tag — full clone + checkout.
        subprocess.run(
            ["git", "clone", "--quiet", "https://github.com/moritztucher/PASKit.git", tmp],
            check=True,
        )
        subprocess.run(["git", "-C", tmp, "checkout", "--quiet", rev], check=True)
    return tmp, notes


def find_pinned_revision(roots: list[str]) -> Optional[str]:
    candidates = []
    for root in roots:
        try:
            top = subprocess.run(
                ["git", "-C", root, "rev-parse", "--show-toplevel"],
                capture_output=True, text=True, check=True,
            ).stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            top = root
        for dirpath, dirnames, filenames in os.walk(top):
            if "Package.resolved" in filenames:
                candidates.append(os.path.join(dirpath, "Package.resolved"))
        break  # only the first ROOT, per spec
    for path in candidates:
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError):
            continue
        pins = data.get("pins", data.get("object", {}).get("pins", []))
        for pin in pins:
            identity = pin.get("identity", "")
            if identity.lower() == "paskit":
                rev = pin.get("state", {}).get("revision")
                if rev:
                    return rev
    return None


# --------------------------------------------------------------------------
# Local repo scanning
# --------------------------------------------------------------------------

DEFAULT_EXCLUDE_DIRS = {".build", "build", "DerivedData", "SourcePackages", "Pods", "Carthage", ".git"}


def is_excluded_dir(dirpath: str, extra_globs: list[str]) -> bool:
    base = os.path.basename(dirpath)
    if base in DEFAULT_EXCLUDE_DIRS or base.endswith(".xcodeproj"):
        return True
    if os.path.isfile(os.path.join(dirpath, "Package.swift")):
        try:
            with open(os.path.join(dirpath, "Package.swift"), "r", encoding="utf-8", errors="replace") as f:
                head = f.read(500)
            if 'name: "PASKit"' in head or 'name:"PASKit"' in head:
                return True
        except OSError:
            pass
    for pattern in extra_globs:
        if fnmatch.fnmatch(dirpath, pattern) or fnmatch.fnmatch(base, pattern):
            return True
    return False


def scan_root(root: str, extra_excludes: list[str]) -> tuple[list[Decl], set[str], int]:
    decls: list[Decl] = []
    imports: set[str] = set()
    file_count = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d for d in dirnames
            if not is_excluded_dir(os.path.join(dirpath, d), extra_excludes)
        ]
        for fn in filenames:
            if fn.endswith(".swift"):
                path = os.path.join(dirpath, fn)
                file_decls, file_imports = parse_file(path, root)
                decls.extend(file_decls)
                imports.update(file_imports)
                file_count += 1
    return decls, imports, file_count


# --------------------------------------------------------------------------
# Allowlist
# --------------------------------------------------------------------------


@dataclass
class AllowEntry:
    kind: str  # 'type' | 'extension'
    symbol: str  # 'AppInfo' or 'View.presentAppRating'
    path: Optional[str]
    justification: str
    line: int
    matched: bool = False


ALLOW_ENTRY_RE = re.compile(
    r"^\s*(type|extension)\s+(\S+)(?:\s+@\s+(\S+))?\s*--\s*(.*)$"
)


def parse_allowlist(path: str) -> list[AllowEntry]:
    entries: list[AllowEntry] = []
    if not os.path.isfile(path):
        return entries
    with open(path, "r", encoding="utf-8") as f:
        raw_lines = f.readlines()
    for i, raw in enumerate(raw_lines):
        line = raw.rstrip("\n")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = ALLOW_ENTRY_RE.match(line)
        if not m:
            print(f"error: allowlist {path}:{i + 1}: malformed entry: {line!r}", file=sys.stderr)
            sys.exit(2)
        kind, symbol, entry_path, justification = m.groups()
        if not justification.strip():
            print(
                f"error: allowlist {path}:{i + 1}: no justification for '{kind} {symbol}' "
                f"(every entry needs a '-- <why>')",
                file=sys.stderr,
            )
            sys.exit(2)
        entries.append(AllowEntry(kind=kind, symbol=symbol, path=entry_path, justification=justification.strip(), line=i + 1))
    return entries


def allowlist_lookup(entries: list[AllowEntry], kind: str, symbol: str, local_path: str) -> Optional[AllowEntry]:
    for e in entries:
        if e.kind != kind or e.symbol != symbol:
            continue
        if e.path and e.path != local_path:
            continue
        e.matched = True
        return e
    return None


# --------------------------------------------------------------------------
# Rules
# --------------------------------------------------------------------------


@dataclass
class Finding:
    cls: str  # 'type/full' | 'type/partial' | 'type/name-only' | 'extension/full' | 'extension/overload'
    severity: str  # 'error' | 'warning'
    symbol: str
    local_file: str
    local_line: int
    local_imports_paskit: bool
    paskit_module: str
    paskit_file: str
    paskit_line: int
    extra: dict = field(default_factory=dict)


def local_type_members(decls: list[Decl], type_name: str) -> set[str]:
    return {
        d.name
        for d in decls
        if d.parent_name == type_name and d.kind in ("func", "var", "let", "case")
    }


def _labels_share_prefix(a: str, b: str) -> bool:
    """True when the argument-label sequence of `a` is a strict prefix of
    `b`'s, or vice versa — the shape that lets a shorter call site resolve
    against either declaration when the longer one's extra trailing labels
    have default values."""
    a_parts = a[:-1].split(":") if a.endswith(":") else a.split(":")
    b_parts = b[:-1].split(":") if b.endswith(":") else b.split(":")
    if a == "" or b == "":
        a_parts, b_parts = ([] if a == "" else a_parts), ([] if b == "" else b_parts)
    if not a_parts or not b_parts:
        return False
    if a_parts == b_parts:
        return False  # equality is handled by the caller before this is reached
    shorter, longer = (a_parts, b_parts) if len(a_parts) < len(b_parts) else (b_parts, a_parts)
    return longer[: len(shorter)] == shorter


def run_rules_full(
    local_decls: list[Decl],
    surface: list[Symbol],
    paskit_type_members: dict[str, set[str]],
) -> list[Finding]:
    findings: list[Finding] = []

    t_by_name: dict[str, Symbol] = {}
    x_by_key: dict[tuple[str, str], list[Symbol]] = {}
    for s in surface:
        if s.kind == "T":
            t_by_name.setdefault(s.name, s)
        elif s.kind == "X":
            x_by_key.setdefault((s.extension_of, s.name), []).append(s)

    # Rule T
    for d in local_decls:
        if d.parent_kind is not None:
            continue
        if d.kind not in ("struct", "class", "enum", "actor", "protocol", "typealias"):
            continue
        sym = t_by_name.get(d.name)
        if not sym:
            continue
        L = local_type_members(local_decls, d.name)
        P = paskit_type_members.get(d.name, set())
        overlap = L & P
        extra = L - P
        if not L or L <= P:
            cls, sev = "type/full", "error"
        elif overlap:
            cls, sev = "type/partial", "error"
        else:
            cls, sev = "type/name-only", "warning"
        findings.append(
            Finding(
                cls=cls,
                severity=sev,
                symbol=d.name,
                local_file=d.file,
                local_line=d.line,
                local_imports_paskit=False,  # filled by caller
                paskit_module=sym.module,
                paskit_file=sym.file,
                paskit_line=sym.line,
                extra={"overlap": sorted(overlap), "extra": sorted(extra)},
            )
        )

    # Rule X
    for d in local_decls:
        if d.parent_kind != "extension":
            continue
        if d.kind not in ("func", "var", "subscript", "init"):
            continue
        # Compare extended type by last path component.
        ext_of = d.parent_name.split(".")[-1] if d.parent_name else d.parent_name
        key = (ext_of, d.name)
        candidates = x_by_key.get(key)
        if not candidates:
            continue
        sym = candidates[0]
        local_labels = d.labels or ""
        paskit_labels = sym.labels or ""
        if local_labels == paskit_labels:
            cls = "extension/full"
        elif _labels_share_prefix(local_labels, paskit_labels):
            # One label sequence is a strict prefix of the other — a call
            # site short enough to omit the extra (presumably defaulted)
            # trailing labels could resolve against either declaration.
            # This is the presentAppRating shape: WorkoutApp's local
            # `(initialCondition:askLaterCondition:)` is a prefix of
            # PASKit's `(initialCondition:askLaterCondition:keys:copy:)`.
            cls = "extension/overload"
        else:
            # Disjoint label sequences (e.g. `init(hex:)` vs.
            # `init(light:dark:)`) are unambiguous, legitimate Swift
            # overloads — no call site can resolve to both, so this is not
            # a shadowing risk and is not reported.
            continue
        symbol_str = f"{ext_of}.{d.name}"
        findings.append(
            Finding(
                cls=cls,
                severity="error",
                symbol=symbol_str,
                local_file=d.file,
                local_line=d.line,
                local_imports_paskit=False,
                paskit_module=sym.module,
                paskit_file=sym.file,
                paskit_line=sym.line,
                extra={"local_labels": local_labels, "paskit_labels": paskit_labels},
            )
        )

    return findings


def build_paskit_type_members(paskit_root: str, surface: list[Symbol]) -> dict[str, set[str]]:
    """For Rule T's overlap check: member names ('func|var|let|case') of
    each PASKit top-level type, any access level (matches the local side,
    which is also collected at any access level)."""
    t_names = {s.name for s in surface if s.kind == "T"}
    sources_dir = os.path.join(paskit_root, "Sources")
    result: dict[str, set[str]] = {name: set() for name in t_names}
    for module in os.listdir(sources_dir):
        mod_path = os.path.join(sources_dir, module)
        if module == "PASKit" or not os.path.isdir(mod_path):
            continue
        for f in _walk_swift_files(mod_path):
            decls, _ = parse_file(f, paskit_root)
            for d in decls:
                if d.parent_name in result and d.kind in ("func", "var", "let", "case"):
                    result[d.parent_name].add(d.name)
    return result


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------


def format_human(finding: Finding, imports: bool) -> str:
    lines = []
    lines.append(f"{finding.severity.upper()} {finding.cls}  {finding.symbol}")
    import_note = "file imports PASKit" if imports else "file does not import PASKit"
    lines.append(f"  local : {finding.local_file}:{finding.local_line}  ({import_note})")
    lines.append(f"  paskit: {finding.paskit_module}  {finding.paskit_file}:{finding.paskit_line}")
    if finding.cls == "type/partial":
        overlap = ", ".join(finding.extra.get("overlap", [])) or "(none)"
        extra = ", ".join(finding.extra.get("extra", [])) or "(none)"
        lines.append(f"  overlap: {overlap}        extra (app-owned): {extra}")
        lines.append(
            f"  fix   : rename the local type so PASKit's {finding.symbol} is reachable unqualified, or allowlist:\n"
            f"          type {finding.symbol} -- <why>"
        )
    elif finding.cls == "type/full":
        lines.append(
            f"  fix   : delete the local type and use PASKit's {finding.symbol}, or allowlist:\n"
            f"          type {finding.symbol} -- <why this app must keep its own copy>"
        )
    elif finding.cls == "type/name-only":
        lines.append("  note  : unrelated members — same name only, forces module qualification but is not a duplicate")
    elif finding.cls in ("extension/full", "extension/overload"):
        lines.append(f"  why   : same-module declarations shadow imported ones — a call site now runs the local copy.")
        lines.append(
            f"  fix   : delete the local declaration and call PASKit's, or allowlist:\n"
            f"          extension {finding.symbol} -- <why this app must keep its own copy>"
        )
    return "\n".join(lines)


def format_github(finding: Finding) -> str:
    level = "error" if finding.severity == "error" else "warning"
    title = f"PASKit collision ({finding.cls})"
    msg = f"{finding.symbol} collides with PASKit {finding.paskit_module}/{finding.paskit_file}:{finding.paskit_line}"
    return f"::{level} file={finding.local_file},line={finding.local_line},title={title}::{msg}"


# --------------------------------------------------------------------------
# Self-check
# --------------------------------------------------------------------------

# Coarse guard: T + X + members-of-PASKit's-own-types (M), which is the
# fuller "how much public surface did the parser actually read" number.
# Calibrated against PASKit @ v0.3.2 (T=80, X=45, M=403 -> 528); a future
# syntax pattern the parser can't read would drop this well below 450.
SELF_CHECK_MIN_TOTAL = 450
SELF_CHECK_SENTINELS = [
    ("T", None, "AppInfo"),
    ("T", None, "WhatsNewView"),
    ("T", None, "PASPressableButtonStyle"),
    ("X", "View", "presentAppRating"),
    ("X", "View", "pasGlass"),
    ("X", "ButtonStyle", "pasPressable"),
    ("X", "Animation", "respectingReducedMotion"),
    ("X", "URLRequest", None),  # any one member
]


def self_check(paskit_root: str, surface: list[Symbol]) -> int:
    ok = True
    type_members = build_paskit_type_members(paskit_root, surface)
    total = len(surface) + sum(len(v) for v in type_members.values())
    if total < SELF_CHECK_MIN_TOTAL:
        print(f"self-check FAIL: only {total} declarations extracted (expected >= {SELF_CHECK_MIN_TOTAL})", file=sys.stderr)
        ok = False
    for kind, ext_of, name in SELF_CHECK_SENTINELS:
        if kind == "T":
            found = any(s.kind == "T" and s.name == name for s in surface)
        elif name is None:
            found = any(s.kind == "X" and s.extension_of == ext_of for s in surface)
        else:
            found = any(s.kind == "X" and s.extension_of == ext_of and s.name == name for s in surface)
        if not found:
            label = name if kind == "T" else f"{ext_of}.{name or '<any>'}"
            print(f"self-check FAIL: sentinel {kind}:{label} not found in extracted surface — parser regressed", file=sys.stderr)
            ok = False
    if ok:
        print(f"self-check OK: {total} declarations ({len(surface)} public surface symbols), all sentinels present")
    return 0 if ok else 2


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Detect app declarations that collide with PASKit's public surface.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("roots", nargs="*", default=["."], metavar="ROOT")
    p.add_argument("--paskit", metavar="PATH")
    p.add_argument("--paskit-rev", metavar="REV")
    p.add_argument("--allowlist", metavar="PATH")
    p.add_argument("--exclude", action="append", default=[], metavar="GLOB")
    p.add_argument("--format", choices=["human", "github", "json"], default="human")
    p.add_argument("--warn-only", action="store_true")
    p.add_argument("--strict-allowlist", action="store_true")
    p.add_argument("--dump-surface", nargs="?", const="-", default=None, metavar="FILE")
    p.add_argument("--self-check", action="store_true")
    p.add_argument("--verbose", action="store_true")
    return p


def main(argv: list[str]) -> int:
    args = build_arg_parser().parse_args(argv)

    if args.self_check:
        paskit_root = args.paskit or "."
        if not os.path.isfile(os.path.join(paskit_root, "Package.swift")):
            print(f"error: --self-check must be run from (or --paskit pointed at) a PASKit checkout", file=sys.stderr)
            return 2
        surface = build_surface(paskit_root)
        return self_check(paskit_root, surface)

    paskit_root, notes = resolve_paskit_root(args)
    for note in notes:
        print(note)
    surface = build_surface(paskit_root)

    if args.dump_surface is not None:
        lines = []
        for s in sorted(surface, key=lambda s: (s.module, s.kind, s.extension_of or "", s.name)):
            if s.kind == "T":
                lines.append(f"T:{s.name}\t{s.module}\t{s.file}:{s.line}")
            elif s.kind == "X":
                labels = s.labels or ""
                lines.append(f"X:{s.extension_of}.{s.name}({labels})\t{s.module}\t{s.file}:{s.line}")
            elif s.kind == "F":
                lines.append(f"F:{s.name}\t{s.module}\t{s.file}:{s.line}")
            elif s.kind == "O":
                lines.append(f"O:{s.name}\t{s.module}\t{s.file}:{s.line}")
        out = "\n".join(lines) + "\n"
        if args.dump_surface == "-":
            sys.stdout.write(out)
        else:
            with open(args.dump_surface, "w", encoding="utf-8") as f:
                f.write(out)
        return 0

    paskit_type_members = build_paskit_type_members(paskit_root, surface)

    total_errors = 0
    total_warnings = 0
    total_allowed = 0
    total_stale = 0
    total_files = 0

    for root in args.roots:
        try:
            git_top = subprocess.run(
                ["git", "-C", root, "rev-parse", "--show-toplevel"],
                capture_output=True, text=True, check=True,
            ).stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            git_top = os.path.abspath(root)

        decls, imports, file_count = scan_root(root, args.exclude)
        total_files += file_count

        linked_modules: set[str]
        if "PASKit" in imports:
            linked_modules = {s.module for s in surface}
        else:
            linked_modules = imports & {s.module for s in surface}

        if not linked_modules:
            print(f"note: {root} imports no PASKit module — skipped")
            continue

        module_surface = [s for s in surface if s.module in linked_modules]

        allowlist_path = args.allowlist or os.path.join(git_top, ".paskit-collisions-allow")
        allow_entries = parse_allowlist(allowlist_path)

        # Which files import PASKit, for the "(file imports PASKit)" note.
        files_importing: dict[str, bool] = {}
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if not is_excluded_dir(os.path.join(dirpath, d), args.exclude)]
            for fn in filenames:
                if fn.endswith(".swift"):
                    path = os.path.join(dirpath, fn)
                    rel = os.path.relpath(path, root)
                    with open(path, "r", encoding="utf-8", errors="replace") as f:
                        head = f.read(4000)
                    files_importing[rel] = bool(re.search(r"^\s*import\s+PASKit", head, re.MULTILINE))

        findings = run_rules_full(decls, module_surface, paskit_type_members)

        for finding in findings:
            local_path = os.path.relpath(os.path.join(root, finding.local_file), git_top)
            kind = "type" if finding.cls.startswith("type/") else "extension"
            allow = allowlist_lookup(allow_entries, kind, finding.symbol, local_path)
            finding.local_imports_paskit = files_importing.get(finding.local_file, False)

            if allow:
                total_allowed += 1
                if args.verbose:
                    print(f"ALLOWED {finding.cls}  {finding.symbol}  -- {allow.justification}")
                continue

            if finding.severity == "error":
                total_errors += 1
            else:
                total_warnings += 1

            if args.format == "human":
                print(format_human(finding, finding.local_imports_paskit))
                print()
            elif args.format == "github":
                print(format_github(finding))
            elif args.format == "json":
                print(json.dumps(asdict(finding)))

        for entry in allow_entries:
            if not entry.matched:
                total_stale += 1
                msg = f"stale allowlist entry: {entry.kind} {entry.symbol}"
                if entry.path:
                    msg += f" @ {entry.path}"
                msg += " matched nothing — remove it"
                if args.strict_allowlist:
                    total_errors += 1
                    print(f"ERROR {msg}")
                else:
                    print(f"WARN {msg}")

    summary = (
        f"paskit-collisions: {total_errors} error{'s' if total_errors != 1 else ''}, "
        f"{total_warnings} warning{'s' if total_warnings != 1 else ''}, "
        f"{total_allowed} allowlisted, {total_stale} stale allowlist entr{'ies' if total_stale != 1 else 'y'}  "
        f"(surface: {len(surface)} symbols, {len({s.module for s in surface})} modules; scanned {total_files} files)"
    )
    print(summary)

    if total_errors > 0:
        return 0 if args.warn_only else 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
