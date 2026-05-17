#!/usr/bin/env python3
"""Preflight read-only check for the cbq wrapper.

Reads SQL++ text on stdin (one or more statements, separated however) and
exits with code 0 if it contains only read-shaped statements. If any
forbidden write/DDL keyword appears outside of string literals, quoted
identifiers, or comments, prints a comma-separated list of the matched
keywords and exits with code 3.

This is a hard guard, intentionally conservative: false positives block a
read query (annoying but the user can rephrase or backtick the name); a
false negative could mutate the cluster, which the skill is forbidden to
do under any circumstance.
"""
from __future__ import annotations

import re
import sys

FORBIDDEN = [
    "INSERT", "UPDATE", "UPSERT", "DELETE", "MERGE",
    "CREATE", "DROP", "ALTER", "TRUNCATE", "GRANT", "REVOKE",
    "RENAME", "BUILD",
]


def strip_noise(text: str) -> str:
    """Remove string literals, backtick-quoted identifiers, and comments so
    keyword search only inspects executable SQL tokens."""
    text = re.sub(r"'(?:[^'\\]|\\.)*'", "", text)
    text = re.sub(r'"(?:[^"\\]|\\.)*"', "", text)
    text = re.sub(r"`[^`]*`", "", text)
    text = re.sub(r"--[^\n]*", "", text)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return text


def find_forbidden(text: str) -> list[str]:
    stripped = strip_noise(text)
    hits: list[str] = []
    for kw in FORBIDDEN:
        if re.search(r"\b" + kw + r"\b", stripped, re.I):
            hits.append(kw)
    return hits


def main() -> int:
    text = sys.stdin.read()
    if not text.strip():
        return 0
    hits = find_forbidden(text)
    if hits:
        sys.stdout.write(",".join(hits))
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
