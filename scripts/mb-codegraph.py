#!/usr/bin/env python3
"""Python AST-based code graph builder for Memory Bank.

Usage:
    mb-codegraph.py [--dry-run|--apply] [mb_path] [src_root]

Parses ``src_root/**/*.py``, extracts functions/classes/imports/calls/inherits,
builds a graph, writes outputs (``--apply`` only):

  * ``<mb>/codebase/graph.json`` — JSON Lines (one node/edge per line)
  * ``<mb>/codebase/god-nodes.md`` — top-20 by in+out degree
  * ``<mb>/codebase/.cache/<file-slug>.json`` — per-file SHA256 → parsed entities

Incremental: files whose SHA256 matches cache are skipped (summary reports
``reparsed=N cached=M``). Tree-sitter adapter for non-Python languages —
Stage 6.5 opt-in extras (see BACKLOG).
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any

TOP_GOD_NODES = 20


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=f".{path.name}.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def _rel(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


class _Extractor(ast.NodeVisitor):
    """Walk AST, collect nodes + edges for a single file."""

    def __init__(self, file_rel: str) -> None:
        self.file = file_rel
        self.nodes: list[dict[str, Any]] = []
        self.edges: list[dict[str, Any]] = []
        self._scope: list[str] = []

    def _qualname(self, name: str) -> str:
        return ".".join(self._scope + [name]) if self._scope else name

    def _current_src(self) -> str:
        return f"{self.file}:{self._qualname('')}".rstrip(".:")

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self._handle_function(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        self._handle_function(node)

    def _handle_function(self, node: ast.AST) -> None:
        name = getattr(node, "name", "?")
        self.nodes.append({
            "kind": "function",
            "name": self._qualname(name),
            "file": self.file,
            "line": getattr(node, "lineno", 0),
        })
        self._scope.append(name)
        try:
            self.generic_visit(node)
        finally:
            self._scope.pop()

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        name = node.name
        self.nodes.append({
            "kind": "class",
            "name": self._qualname(name),
            "file": self.file,
            "line": node.lineno,
        })
        # Inheritance edges
        for base in node.bases:
            base_name = _name_of(base)
            if base_name:
                self.edges.append({
                    "src": f"{self.file}:{self._qualname(name)}",
                    "dst": base_name,
                    "kind": "inherit",
                })
        self._scope.append(name)
        try:
            self.generic_visit(node)
        finally:
            self._scope.pop()

    def visit_Import(self, node: ast.Import) -> None:
        for alias in node.names:
            self.edges.append({
                "src": self.file,
                "dst": alias.name,
                "kind": "import",
            })

    def visit_ImportFrom(self, node: ast.ImportFrom) -> None:
        mod = node.module or ""
        for alias in node.names:
            target = f"{mod}.{alias.name}" if mod else alias.name
            self.edges.append({
                "src": self.file,
                "dst": target,
                "kind": "import",
            })

    def visit_Call(self, node: ast.Call) -> None:
        target = _name_of(node.func)
        if target:
            src = f"{self.file}:{self._qualname('')}".rstrip(".:")
            self.edges.append({
                "src": src or self.file,
                "dst": target,
                "kind": "call",
            })
        self.generic_visit(node)


def _name_of(expr: ast.AST) -> str:
    """Best-effort name extraction from Name / Attribute / Subscript expressions."""
    if isinstance(expr, ast.Name):
        return expr.id
    if isinstance(expr, ast.Attribute):
        inner = _name_of(expr.value)
        return f"{inner}.{expr.attr}" if inner else expr.attr
    if isinstance(expr, ast.Call):
        return _name_of(expr.func)
    return ""


def parse_file(py_path: Path, src_root: Path) -> dict[str, Any]:
    """Parse a single .py file → {nodes, edges, hash}. Raises SyntaxError on bad syntax."""
    text = py_path.read_text(encoding="utf-8")
    tree = ast.parse(text, filename=str(py_path))
    rel = _rel(py_path, src_root)
    extractor = _Extractor(rel)
    # Module node
    extractor.nodes.append({
        "kind": "module",
        "name": rel,
        "file": rel,
        "line": 1,
    })
    extractor.visit(tree)
    return {
        "nodes": extractor.nodes,
        "edges": extractor.edges,
        "hash": _sha256(text),
        "file": rel,
    }


def _cache_slug(rel_path: str) -> str:
    return hashlib.sha256(rel_path.encode("utf-8")).hexdigest()[:16]


def _load_cache(cache_dir: Path, rel_path: str) -> dict[str, Any] | None:
    cache_file = cache_dir / f"{_cache_slug(rel_path)}.json"
    if not cache_file.exists():
        return None
    try:
        return json.loads(cache_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _save_cache(cache_dir: Path, rel_path: str, data: dict[str, Any]) -> None:
    cache_file = cache_dir / f"{_cache_slug(rel_path)}.json"
    _atomic_write(cache_file, json.dumps(data, ensure_ascii=False, indent=2))


def build_graph(
    src_root: Path,
    cache_dir: Path | None = None,
) -> dict[str, Any]:
    """Walk src_root/**/*.py, parse each, aggregate nodes+edges.

    If cache_dir provided: skip re-parse when file hash matches cache.
    Returns aggregated {"nodes": [...], "edges": [...], "reparsed": N, "cached": M}.
    """
    all_nodes: list[dict[str, Any]] = []
    all_edges: list[dict[str, Any]] = []
    reparsed = 0
    cached = 0

    if not src_root.exists():
        return {"nodes": [], "edges": [], "reparsed": 0, "cached": 0}

    py_files = sorted(src_root.rglob("*.py"))
    for py in py_files:
        # Skip hidden dirs (like .venv, __pycache__)
        parts = py.relative_to(src_root).parts
        if any(p.startswith(".") or p == "__pycache__" for p in parts[:-1]):
            continue

        rel = _rel(py, src_root)
        text: str
        try:
            text = py.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        content_hash = _sha256(text)

        # Cache check
        if cache_dir is not None:
            cached_data = _load_cache(cache_dir, rel)
            if cached_data and cached_data.get("hash") == content_hash:
                all_nodes.extend(cached_data.get("nodes", []))
                all_edges.extend(cached_data.get("edges", []))
                cached += 1
                continue

        # Parse
        try:
            result = parse_file(py, src_root)
        except SyntaxError as e:
            print(f"[warn] {rel}: syntax error skipped — {e.msg}", file=sys.stderr)
            continue
        except Exception as e:  # noqa: BLE001 — robust batch
            print(f"[warn] {rel}: parse failed — {e}", file=sys.stderr)
            continue

        all_nodes.extend(result["nodes"])
        all_edges.extend(result["edges"])
        reparsed += 1

        if cache_dir is not None:
            _save_cache(cache_dir, rel, result)

    return {"nodes": all_nodes, "edges": all_edges, "reparsed": reparsed, "cached": cached}


def _compute_degree(graph: dict[str, Any]) -> dict[str, int]:
    """Return {node_name: in+out degree}. Uses name matching (target in edge.dst)."""
    degree: dict[str, int] = {}
    node_names = {n["name"] for n in graph["nodes"]}
    for e in graph["edges"]:
        # Out-degree: edge starts at src (file or file:qualname)
        src_key = e["src"].split(":")[-1] if ":" in e["src"] else e["src"]
        degree[src_key] = degree.get(src_key, 0) + 1
        # In-degree: dst matches one of node names (suffix match for qualified names)
        dst = e["dst"]
        for name in node_names:
            short = name.split(".")[-1]
            if dst == name or dst == short or dst.endswith(f".{short}"):
                degree[name] = degree.get(name, 0) + 1
                break
    return degree


def _render_god_nodes(graph: dict[str, Any]) -> str:
    """Top-N nodes by degree → markdown with file:line links."""
    degree = _compute_degree(graph)
    ranked = sorted(degree.items(), key=lambda kv: -kv[1])[:TOP_GOD_NODES]
    node_lookup = {n["name"]: n for n in graph["nodes"]}

    lines = [
        "# God nodes — top by degree (in + out)",
        "",
        "Автоматически сгенерировано `mb-codegraph.py`. Топ-узлы по связям — кандидаты на рефакторинг или декомпозицию при высокой сложности.",
        "",
        "| # | Name | Kind | File:Line | Degree |",
        "|---|------|------|-----------|--------|",
    ]
    for i, (name, deg) in enumerate(ranked, 1):
        node = node_lookup.get(name)
        kind = node.get("kind", "?") if node else "?"
        loc = (f"{node.get('file', '?')}:{node.get('line', '?')}" if node else "—")
        lines.append(f"| {i} | `{name}` | {kind} | {loc} | {deg} |")
    lines.append("")
    return "\n".join(lines)


def _write_graph_jsonl(graph: dict[str, Any], target: Path) -> None:
    lines: list[str] = []
    for n in graph["nodes"]:
        lines.append(json.dumps({"type": "node", **n}, ensure_ascii=False))
    for e in graph["edges"]:
        lines.append(json.dumps({"type": "edge", **e}, ensure_ascii=False))
    _atomic_write(target, "\n".join(lines) + "\n")


def run(
    *,
    mb_path: str,
    src_root: str,
    mode: str = "dry-run",
) -> dict[str, Any]:
    """Build graph, optionally write outputs. Returns summary dict."""
    mb = Path(mb_path)
    src = Path(src_root)
    if not mb.is_dir():
        raise FileNotFoundError(f"mb_path not found: {mb}")
    if not src.is_dir():
        raise FileNotFoundError(f"src_root not found: {src}")

    codebase = mb / "codebase"
    codebase.mkdir(exist_ok=True)
    cache_dir = codebase / ".cache" if mode == "apply" else None
    if cache_dir is not None:
        cache_dir.mkdir(exist_ok=True)

    graph = build_graph(src, cache_dir)
    node_count = len(graph["nodes"])
    edge_count = len(graph["edges"])

    summary = {
        "nodes": node_count,
        "edges": edge_count,
        "reparsed": graph.get("reparsed", 0),
        "cached": graph.get("cached", 0),
        "mode": mode,
    }

    print(f"nodes={node_count}")
    print(f"edges={edge_count}")
    print(f"reparsed={summary['reparsed']}")
    print(f"cached={summary['cached']}")
    print(f"mode={mode}")

    if mode != "apply":
        return summary

    _write_graph_jsonl(graph, codebase / "graph.json")
    _atomic_write(codebase / "god-nodes.md", _render_god_nodes(graph))

    return summary


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Python code graph builder for Memory Bank")
    parser.add_argument("--apply", action="store_true",
                        help="Write graph.json + god-nodes.md (default: dry-run)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Stdout summary only (default)")
    parser.add_argument("mb_path", nargs="?", default=".memory-bank")
    parser.add_argument("src_root", nargs="?", default=".")
    args = parser.parse_args(argv[1:])

    mode = "apply" if args.apply else "dry-run"
    try:
        run(mb_path=args.mb_path, src_root=args.src_root, mode=mode)
    except FileNotFoundError as e:
        print(f"[error] {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
