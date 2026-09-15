#!/usr/bin/env python3
"""Validate the AI Tech Lead Skill package using only the Python standard library."""

from __future__ import annotations

import re
import sys
import hashlib
from pathlib import Path

try:
    import tomllib
except ImportError:  # pragma: no cover
    tomllib = None

ROOT = Path(__file__).resolve().parent
SKILL = ROOT / "ai-tech-lead"
ERRORS: list[str] = []
WARNINGS: list[str] = []


def error(message: str) -> None:
    ERRORS.append(message)


def warning(message: str) -> None:
    WARNINGS.append(message)


def parse_frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        error(f"{path.relative_to(ROOT)}: frontmatter must start on line 1")
        return {}
    try:
        end = lines[1:].index("---") + 1
    except ValueError:
        error(f"{path.relative_to(ROOT)}: closing frontmatter marker not found")
        return {}
    result: dict[str, str] = {}
    for line_number, line in enumerate(lines[1:end], start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            result[match.group(1)] = match.group(2).strip()
        else:
            error(f"{path.relative_to(ROOT)}:{line_number}: invalid frontmatter line")
    return result


def validate_skill() -> None:
    skill_md = SKILL / "SKILL.md"
    if not skill_md.is_file():
        error("ai-tech-lead/SKILL.md is missing")
        return
    fm = parse_frontmatter(skill_md)
    if fm.get("name") != "ai-tech-lead":
        error("SKILL.md name must be ai-tech-lead")
    if len(fm.get("description", "")) < 80:
        error("SKILL.md description is missing or too short")

    required = [
        "references/model-routing-and-roles.md",
        "references/delegation-standard.md",
        "references/task-contract-standard.md",
        "references/risk-and-quality-gates.md",
        "references/testing-and-acceptance.md",
        "references/code-review-standard.md",
        "references/integration-and-signoff.md",
        "references/failure-and-escalation.md",
        "references/external-agent-preflight.md",
        "assets/DELEGATION_PLAN_TEMPLATE.md",
        "assets/TASK_CONTRACT_TEMPLATE.md",
        "assets/ACCEPTANCE_MATRIX_TEMPLATE.md",
        "assets/SUBAGENT_DELIVERY_TEMPLATE.md",
        "assets/FINAL_SIGNOFF_TEMPLATE.md",
        "assets/PROJECT_QUALITY_PROFILE_TEMPLATE.md",
        "assets/PROJECT_INSTRUCTION_SNIPPET.md",
        "agents/openai.yaml",
    ]
    for rel in required:
        if not (SKILL / rel).is_file():
            error(f"Missing required skill file: ai-tech-lead/{rel}")

    pi_readme = ROOT / "integrations" / "pi" / "README.md"
    if not pi_readme.is_file():
        error("Missing required integration guide: integrations/pi/README.md")


def validate_markdown_links() -> None:
    link_pattern = re.compile(r"\[[^\]]+\]\((<[^>]+>|[^)\s]+)(?:\s+\"[^\"]*\")?\)")
    for path in ROOT.rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        for target in link_pattern.findall(text):
            target = target.strip("<>")
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            clean = target.split("#", 1)[0]
            if not clean:
                continue
            resolved = (path.parent / clean).resolve()
            try:
                resolved.relative_to(ROOT)
            except ValueError:
                error(f"Markdown link escapes package root in {path.relative_to(ROOT)}: {target}")
                continue
            if not resolved.exists():
                error(f"Broken Markdown link in {path.relative_to(ROOT)}: {target}")


def validate_toml() -> None:
    if tomllib is None:
        print("WARN: Python < 3.11; TOML syntax validation skipped")
        return
    for path in (ROOT / "integrations" / "codex").rglob("*.toml"):
        try:
            data = tomllib.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            error(f"Invalid TOML {path.relative_to(ROOT)}: {exc}")
            continue
        if path.parent.name == "agents":
            for key in ("name", "description", "developer_instructions"):
                if not data.get(key):
                    error(f"{path.relative_to(ROOT)} missing {key}")
            if data.get("sandbox_mode") not in {"read-only", "workspace-write", "danger-full-access"}:
                error(f"{path.relative_to(ROOT)} has unsupported sandbox_mode")

    example = ROOT / "integrations" / "codex" / "config.example.toml"
    if example.is_file() and tomllib is not None:
        data = tomllib.loads(example.read_text(encoding="utf-8"))
        if data.get("features", {}).get("multi_agent") is not True:
            error("integrations/codex/config.example.toml must enable features.multi_agent")


def validate_agent_markdown() -> None:
    for path in (ROOT / "integrations" / "claude-code" / "agents").glob("*.md"):
        fm = parse_frontmatter(path)
        for key in ("name", "description", "tools"):
            if not fm.get(key):
                error(f"{path.relative_to(ROOT)} missing {key}")
        if fm.get("permissionMode") and fm["permissionMode"] not in {
            "default", "acceptEdits", "dontAsk", "plan", "bypassPermissions"
        }:
            error(f"{path.relative_to(ROOT)} has unsupported permissionMode")


def validate_manifest() -> None:
    manifest = ROOT / "MANIFEST.sha256"
    if not manifest.is_file():
        error("MANIFEST.sha256 is missing")
        return

    listed: set[Path] = set()
    for line_number, line in enumerate(manifest.read_text(encoding="utf-8").splitlines(), start=1):
        parts = line.split()
        if len(parts) != 2 or not re.fullmatch(r"[0-9a-fA-F]{64}", parts[0]):
            error(f"MANIFEST.sha256:{line_number}: invalid entry")
            continue
        rel = Path(parts[1].replace("\\", "/")).as_posix()
        if rel.startswith("./"):
            rel = rel[2:]
        target = ROOT / rel
        try:
            target.resolve().relative_to(ROOT)
        except ValueError:
            error(f"MANIFEST.sha256:{line_number}: path escapes package root {rel}")
            continue
        listed.add(Path(rel))
        if not target.is_file():
            error(f"MANIFEST.sha256:{line_number}: missing file {rel}")
            continue
        actual = hashlib.sha256(target.read_bytes()).hexdigest()
        if actual.lower() != parts[0].lower():
            error(f"MANIFEST.sha256:{line_number}: hash mismatch for {rel}")

    actual_files = {
        p.relative_to(ROOT).as_posix()
        for p in ROOT.rglob("*")
        if p.is_file()
        and p.name != "MANIFEST.sha256"
        and p.suffix != ".pyc"
        and "__pycache__" not in p.parts
        and ".git" not in p.parts
    }
    missing_from_manifest = sorted(actual_files - {p.as_posix() for p in listed})
    if missing_from_manifest:
        error("Files missing from MANIFEST.sha256: " + ", ".join(missing_from_manifest))


def validate_yaml_shapes() -> None:
    """Validate the package YAML files without requiring a third-party parser."""
    openai = ROOT / "ai-tech-lead" / "agents" / "openai.yaml"
    text = openai.read_text(encoding="utf-8")
    for key in ("interface:", "policy:", "display_name:", "short_description:", "default_prompt:", "allow_implicit_invocation:"):
        if key not in text:
            error(f"{openai.relative_to(ROOT)} missing expected key {key}")

    cases = ROOT / "evals" / "cases.yaml"
    case_text = cases.read_text(encoding="utf-8")
    if not re.search(r"^version:\s*\d+", case_text, re.MULTILINE):
        error("evals/cases.yaml missing numeric version")
    ids = re.findall(r"^\s*- id:\s*([^\s#]+)", case_text, re.MULTILINE)
    if not ids:
        error("evals/cases.yaml has no cases")
    if len(ids) != len(set(ids)):
        error("evals/cases.yaml contains duplicate case ids")
    if len(ids) < 10:
        warning("evals/cases.yaml has fewer than 10 behavioral cases")
    if not re.search(r"^skill:\s*ai-tech-lead\s*$", case_text, re.MULTILINE):
        error("evals/cases.yaml must target skill ai-tech-lead")
    for block in re.split(r"^\s*- id:\s*[^\n]+\n", case_text, flags=re.MULTILINE)[1:]:
        if "prompt:" not in block or "expect:" not in block:
            error("evals/cases.yaml case is missing prompt or expect")


def validate_external_agent_preflight() -> None:
    """Keep the cross-provider preflight contract from being accidentally removed."""
    path = SKILL / "references" / "external-agent-preflight.md"
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")
    required_phrases = {
        "权限／YOLO": "permission/YOLO gate",
        "最高 thinking": "highest thinking gate",
        "BLOCKED": "blocked fallback",
        "Claude Code": "Claude adapter",
        "Pi": "Pi adapter",
        "Gemini CLI": "Gemini/unknown adapter",
        "不得用人工反复点击 `allow`": "no repeated allow clicking",
    }
    for phrase, label in required_phrases.items():
        if phrase not in text:
            error(f"external-agent-preflight.md missing {label}: {phrase}")


def validate_text_hygiene() -> None:
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".md", ".toml", ".yaml", ".yml", ".ps1", ".sh", ".py"}:
            continue
        data = path.read_bytes()
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            error(f"Non-UTF-8 file: {path.relative_to(ROOT)}")
            continue
        if "\t" in text and path.suffix.lower() in {".yaml", ".yml"}:
            error(f"YAML contains tab indentation: {path.relative_to(ROOT)}")
        if path.name != "validate.py" and "TODO: FILL REQUIRED" in text:
            error(f"Unresolved required placeholder: {path.relative_to(ROOT)}")


def main() -> int:
    validate_skill()
    validate_markdown_links()
    validate_toml()
    validate_agent_markdown()
    validate_manifest()
    validate_yaml_shapes()
    validate_external_agent_preflight()
    validate_text_hygiene()

    if ERRORS:
        print("Validation failed:")
        for item in ERRORS:
            print(f"- {item}")
        return 1

    for item in WARNINGS:
        print(f"WARN: {item}")
    file_count = sum(1 for p in ROOT.rglob("*") if p.is_file())
    print(f"Validation passed: {file_count} files checked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
