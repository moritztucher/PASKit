"""
Unit tests for Scripts/check-collisions.py.

Run with:
    python3 -m unittest discover -s Scripts/tests -v

Two layers:
  - In-process unit tests of the pure parsing/rule functions, importing the
    script directly (it has a hyphenated filename, so it's loaded via
    importlib rather than a normal `import`).
  - End-to-end tests that invoke the script as a subprocess against the
    fixture trees under Scripts/tests/fixtures/ — a mini "PASKit" checkout
    (fixtures/mini_paskit) and a set of mini app roots, one per rule/case
    from docs/adr/ADR-0002 and the collision-detector plan.
"""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import unittest

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPT_PATH = os.path.join(os.path.dirname(TESTS_DIR), "check-collisions.py")
FIXTURES = os.path.join(TESTS_DIR, "fixtures")
MINI_PASKIT = os.path.join(FIXTURES, "mini_paskit")


def _load_module():
    spec = importlib.util.spec_from_file_location("check_collisions", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules["check_collisions"] = module
    spec.loader.exec_module(module)
    return module


cc = _load_module()


def run_cli(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, SCRIPT_PATH, *args],
        capture_output=True,
        text=True,
    )


def fixture(name: str) -> str:
    return os.path.join(FIXTURES, name)


NO_ALLOWLIST = os.path.join(FIXTURES, "__no_such_allowlist__")


# --------------------------------------------------------------------------
# strip_source
# --------------------------------------------------------------------------


class TestStripSource(unittest.TestCase):
    def test_line_comment_removed(self):
        out = cc.strip_source('let x = 1 // public struct Fake {}\n')
        self.assertNotIn("Fake", out)
        self.assertNotIn("{", out)

    def test_block_comment_removed_multiline(self):
        src = "/* public struct\n Fake {} */\nlet y = 2\n"
        out = cc.strip_source(src)
        self.assertNotIn("Fake", out)
        self.assertEqual(out.count("\n"), src.count("\n"))  # line numbers preserved

    def test_string_literal_contents_blanked(self):
        out = cc.strip_source('let s = "this has a { brace inside"\n')
        self.assertNotIn("{", out)

    def test_triple_quoted_string_blanked(self):
        src = 'let s = """\npublic struct Fake {}\n"""\n'
        out = cc.strip_source(src)
        self.assertNotIn("Fake", out)
        self.assertEqual(out.count("\n"), src.count("\n"))

    def test_escaped_quote_inside_string(self):
        out = cc.strip_source('let s = "a \\" b { c"\nlet real = 1\n')
        # the escaped quote must not end the string early
        self.assertIn("let real = 1", out)


# --------------------------------------------------------------------------
# parse_file — declaration + scope tracking
# --------------------------------------------------------------------------


class TestParseFile(unittest.TestCase):
    def test_public_extension_view_access_inherited(self):
        path = os.path.join(MINI_PASKIT, "Sources", "PASKitCore", "View+Rating.swift")
        decls, imports = cc.parse_file(path, MINI_PASKIT)
        rating = [d for d in decls if d.name == "presentAppRating"]
        self.assertEqual(len(rating), 1)
        d = rating[0]
        self.assertEqual(d.parent_kind, "extension")
        self.assertEqual(d.parent_name, "View")
        self.assertIsNone(d.access)  # inherited, not explicit
        self.assertEqual(d.labels, "initialCondition:keys:")

    def test_internal_type_not_public(self):
        path = os.path.join(MINI_PASKIT, "Sources", "PASKitCore", "AppInfo.swift")
        decls, _ = cc.parse_file(path, MINI_PASKIT)
        helper = [d for d in decls if d.name == "InternalHelper"]
        self.assertEqual(len(helper), 1)
        self.assertIsNone(helper[0].access)  # no explicit keyword -> internal

    def test_comment_and_string_do_not_leak_declarations(self):
        path = os.path.join(MINI_PASKIT, "Sources", "PASKitCore", "AppInfo.swift")
        decls, _ = cc.parse_file(path, MINI_PASKIT)
        self.assertFalse(any(d.name == "Fake" for d in decls))

    def test_private_member_not_leaked_as_public(self):
        path = os.path.join(MINI_PASKIT, "Sources", "PASKitCore", "AppInfo.swift")
        decls, _ = cc.parse_file(path, MINI_PASKIT)
        secret = [d for d in decls if d.name == "secret"]
        self.assertEqual(len(secret), 1)
        self.assertEqual(secret[0].access, "private")

    def test_local_let_inside_function_body_not_attributed_to_container(self):
        # Regression test: a `let`/`var` inside a method body must not be
        # misread as a sibling member of the enclosing type/extension —
        # the scope stack must push an anonymous frame for the method body.
        src = (
            "import Foundation\n"
            "public struct Widget {\n"
            "    public func compute() -> Int {\n"
            "        let localOnly = 42\n"
            "        return localOnly\n"
            "    }\n"
            "}\n"
        )
        tmp = os.path.join(FIXTURES, "_tmp_local_let.swift")
        with open(tmp, "w") as f:
            f.write(src)
        try:
            decls, _ = cc.parse_file(tmp, FIXTURES)
        finally:
            os.remove(tmp)
        local_only = [d for d in decls if d.name == "localOnly"]
        self.assertEqual(len(local_only), 1)
        self.assertNotEqual(local_only[0].parent_name, "Widget")

    def test_init_without_name_token_is_parsed(self):
        src = (
            "import SwiftUI\n"
            "public extension Color {\n"
            "    init(light: Color, dark: Color) {\n"
            "        self = light\n"
            "    }\n"
            "}\n"
        )
        tmp = os.path.join(FIXTURES, "_tmp_init.swift")
        with open(tmp, "w") as f:
            f.write(src)
        try:
            decls, _ = cc.parse_file(tmp, FIXTURES)
        finally:
            os.remove(tmp)
        inits = [d for d in decls if d.kind == "init"]
        self.assertEqual(len(inits), 1)
        self.assertEqual(inits[0].labels, "light:dark:")

    def test_import_detection(self):
        path = os.path.join(FIXTURES, "app_full_collision", "File.swift")
        _, imports = cc.parse_file(path, fixture("app_full_collision"))
        self.assertIn("PASKit", imports)


# --------------------------------------------------------------------------
# Argument-label extraction and prefix comparison
# --------------------------------------------------------------------------


class TestLabels(unittest.TestCase):
    def test_labels_share_prefix_true_for_defaulted_suffix(self):
        self.assertTrue(
            cc._labels_share_prefix(
                "initialCondition:askLaterCondition:",
                "initialCondition:askLaterCondition:keys:copy:",
            )
        )

    def test_labels_share_prefix_false_for_disjoint(self):
        self.assertFalse(cc._labels_share_prefix("hex:", "light:dark:"))

    def test_labels_share_prefix_false_for_equal(self):
        # equality is handled by the caller before reaching this helper
        self.assertFalse(cc._labels_share_prefix("a:b:", "a:b:"))

    def test_underscore_label_recorded_as_empty(self):
        src = (
            "public extension Int {\n"
            "    func pasThing(_ value: Int) -> Int { value }\n"
            "}\n"
        )
        tmp = os.path.join(FIXTURES, "_tmp_underscore.swift")
        with open(tmp, "w") as f:
            f.write(src)
        try:
            decls, _ = cc.parse_file(tmp, FIXTURES)
        finally:
            os.remove(tmp)
        d = [x for x in decls if x.name == "pasThing"][0]
        self.assertEqual(d.labels, ":")


# --------------------------------------------------------------------------
# build_surface
# --------------------------------------------------------------------------


class TestBuildSurface(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.surface = cc.build_surface(MINI_PASKIT)

    def test_umbrella_module_excluded(self):
        self.assertFalse(any(s.name == "ShouldNotAppearInSurface" for s in self.surface))

    def test_public_type_extracted(self):
        self.assertTrue(any(s.kind == "T" and s.name == "AppInfo" for s in self.surface))

    def test_internal_type_not_extracted(self):
        self.assertFalse(any(s.name == "InternalHelper" for s in self.surface))

    def test_extension_member_extracted_with_inherited_access(self):
        hits = [s for s in self.surface if s.kind == "X" and s.extension_of == "View" and s.name == "presentAppRating"]
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0].labels, "initialCondition:keys:")

    def test_animation_extension_extracted(self):
        self.assertTrue(
            any(s.kind == "X" and s.extension_of == "Animation" and s.name == "respectingReducedMotion" for s in self.surface)
        )


# --------------------------------------------------------------------------
# Allowlist parsing
# --------------------------------------------------------------------------


class TestAllowlist(unittest.TestCase):
    def test_valid_entry_parsed(self):
        entries = cc.parse_allowlist(os.path.join(fixture("app_allowlist_ok"), ".paskit-collisions-allow"))
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0].kind, "extension")
        self.assertEqual(entries[0].symbol, "View.presentAppRating")
        self.assertTrue(entries[0].justification)

    def test_missing_justification_exits_2(self):
        with self.assertRaises(SystemExit) as cm:
            cc.parse_allowlist(os.path.join(fixture("app_allowlist_bad"), ".paskit-collisions-allow"))
        self.assertEqual(cm.exception.code, 2)

    def test_missing_file_returns_empty(self):
        self.assertEqual(cc.parse_allowlist(os.path.join(fixture("app_allowlist_ok"), "does-not-exist")), [])

    def test_comments_and_blank_lines_ignored(self):
        entries = cc.parse_allowlist(os.path.join(fixture("app_allowlist_ok"), ".paskit-collisions-allow"))
        # the fixture file has a leading '#' comment line — must not become an entry
        self.assertEqual(len(entries), 1)


# --------------------------------------------------------------------------
# End-to-end CLI behavior against fixtures
# --------------------------------------------------------------------------


class TestCLIEndToEnd(unittest.TestCase):
    def test_self_check_passes_on_real_paskit_checkout(self):
        real_paskit = os.path.dirname(os.path.dirname(TESTS_DIR))
        result = run_cli(["--paskit", real_paskit, "--self-check"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("self-check OK", result.stdout)

    def test_full_extension_collision_detected(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            fixture("app_full_collision"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn("extension/full", result.stdout)
        self.assertIn("View.presentAppRating", result.stdout)

    def test_overload_collision_via_defaulted_suffix(self):
        # local declares only the first label; PASKit's version has two more
        # trailing, defaulted labels -- a real same-module shadowing risk.
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            fixture("app_overload_collision"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn("extension/overload", result.stdout)

    def test_disjoint_labels_not_reported(self):
        # app_silent_method also declares `Color.init(hex:)`, disjoint from
        # PASKit's `Color.init(light:dark:)` were it in the mini surface —
        # here it collides with nothing since mini_paskit has no Color
        # extension at all; the meaningful assertion is the method-in-a-
        # local-type case below staying silent.
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            fixture("app_silent_method"),
        ])
        self.assertEqual(result.returncode, 0)
        self.assertIn("0 errors", result.stdout)

    def test_type_partial_collision(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            fixture("app_partial_type"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn("type/partial", result.stdout)
        self.assertIn("overlap: version", result.stdout)
        self.assertIn("extra (app-owned): extra", result.stdout)

    def test_type_full_collision(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            fixture("app_full_type"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn("type/full", result.stdout)

    def test_type_name_only_is_warning_not_error(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            fixture("app_name_only"),
        ])
        self.assertEqual(result.returncode, 0)
        self.assertIn("type/name-only", result.stdout)
        self.assertIn("0 errors", result.stdout)
        self.assertIn("1 warning", result.stdout)

    def test_root_with_no_paskit_import_is_skipped(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            fixture("app_no_import"),
        ])
        self.assertEqual(result.returncode, 0)
        self.assertIn("imports no PASKit module — skipped", result.stdout)
        self.assertIn("0 errors", result.stdout)

    # NOTE: these fixture roots live inside PASKit's own git checkout, so
    # `--allowlist` is always passed explicitly — the script's *default*
    # allowlist resolution walks up to the scanned root's git top-level
    # (correct behavior for a real app repo), which here would resolve to
    # PASKit's own repo root rather than the fixture directory.

    def test_allowlisted_collision_exits_clean(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", os.path.join(fixture("app_allowlist_ok"), ".paskit-collisions-allow"),
            fixture("app_allowlist_ok"),
        ])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("1 allowlisted", result.stdout)

    def test_allowlist_without_justification_exits_2(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", os.path.join(fixture("app_allowlist_bad"), ".paskit-collisions-allow"),
            fixture("app_allowlist_bad"),
        ])
        self.assertEqual(result.returncode, 2)
        self.assertIn("no justification", result.stderr)

    def test_stale_allowlist_entry_warns_but_stays_green(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", os.path.join(fixture("app_allowlist_stale"), ".paskit-collisions-allow"),
            fixture("app_allowlist_stale"),
        ])
        self.assertEqual(result.returncode, 0)
        self.assertIn("stale allowlist entry", result.stdout)

    def test_stale_allowlist_entry_is_error_with_strict_flag(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", os.path.join(fixture("app_allowlist_stale"), ".paskit-collisions-allow"),
            "--strict-allowlist",
            fixture("app_allowlist_stale"),
        ])
        self.assertEqual(result.returncode, 1)

    def test_warn_only_maps_errors_to_exit_0(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            "--warn-only",
            fixture("app_full_collision"),
        ])
        self.assertEqual(result.returncode, 0)
        self.assertIn("1 error", result.stdout)

    def test_github_format_annotation(self):
        result = run_cli([
            "--paskit", MINI_PASKIT,
            "--allowlist", NO_ALLOWLIST,
            "--format", "github",
            fixture("app_full_collision"),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertTrue(any(line.startswith("::error") for line in result.stdout.splitlines()))

    def test_dump_surface(self):
        result = run_cli(["--paskit", MINI_PASKIT, "--dump-surface"])
        self.assertEqual(result.returncode, 0)
        self.assertIn("T:AppInfo", result.stdout)
        self.assertIn("View.presentAppRating", result.stdout)

    def test_self_check_fails_against_undersized_mini_paskit(self):
        # mini_paskit is deliberately tiny -- self-check's coarse symbol-
        # count guard must correctly reject it, and its sentinel check must
        # report the ones mini_paskit doesn't have.
        result = run_cli(["--paskit", MINI_PASKIT, "--self-check"])
        self.assertEqual(result.returncode, 2)
        self.assertIn("self-check FAIL", result.stderr)


if __name__ == "__main__":
    unittest.main()
