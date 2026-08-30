#!/usr/bin/env python3
"""Bundle Homebrew dynamic-library dependencies into a macOS app."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, capture_output=True)


def dependencies(binary: Path) -> list[str]:
    output = run("/usr/bin/otool", "-L", str(binary)).stdout.splitlines()[1:]
    return [line.strip().split(" (", 1)[0] for line in output if line.strip()]


def rpaths(binary: Path) -> list[str]:
    lines = run("/usr/bin/otool", "-l", str(binary)).stdout.splitlines()
    paths: list[str] = []
    for index, line in enumerate(lines):
        if line.strip() == "cmd LC_RPATH":
            for candidate in lines[index + 1:index + 5]:
                stripped = candidate.strip()
                if stripped.startswith("path "):
                    paths.append(stripped.removeprefix("path ").split(" (offset", 1)[0])
                    break
    return paths


def resolve_dependency(reference: str, owner: Path) -> Path | None:
    if reference.startswith("/opt/homebrew/"):
        candidate = Path(reference)
        return candidate.resolve() if candidate.exists() else None

    name: str | None = None
    if reference.startswith("@rpath/"):
        name = reference.removeprefix("@rpath/")
    elif reference.startswith("@loader_path/"):
        candidate = owner.resolve().parent / reference.removeprefix("@loader_path/")
        if candidate.exists():
            return candidate.resolve()
        name = Path(reference).name

    if not name:
        return None

    candidates = [owner.resolve().parent / name, Path("/opt/homebrew/lib") / name]
    candidates.extend(Path("/opt/homebrew/opt").glob(f"*/lib/{name}"))
    for candidate in candidates:
        if candidate.exists():
            resolved = candidate.resolve()
            if str(resolved).startswith("/opt/homebrew/"):
                return resolved
    return None


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: bundle_dylibs.py EXECUTABLE FRAMEWORKS_DIR", file=sys.stderr)
        return 2

    executable = Path(sys.argv[1]).resolve()
    frameworks = Path(sys.argv[2]).resolve()
    frameworks.mkdir(parents=True, exist_ok=True)

    sources: dict[str, Path] = {}
    pending: list[Path] = [executable]
    visited: set[Path] = set()

    while pending:
        owner = pending.pop()
        resolved_owner = owner.resolve()
        if resolved_owner in visited:
            continue
        visited.add(resolved_owner)

        for reference in dependencies(resolved_owner):
            source = resolve_dependency(reference, resolved_owner)
            if source is None:
                continue
            name = Path(reference).name
            existing = sources.get(name)
            if existing is not None and existing != source:
                raise RuntimeError(f"dynamic-library name collision: {name}\n{existing}\n{source}")
            if existing is None:
                sources[name] = source
                pending.append(source)

    for name, source in sorted(sources.items()):
        destination = frameworks / name
        shutil.copy2(source, destination)
        destination.chmod(destination.stat().st_mode | 0o200)

    # Preserve the license texts shipped in each Homebrew Cellar package.
    # This directory becomes part of the final distributable app.
    licenses_root = frameworks.parent / "Resources" / "Licenses"
    licenses_root.mkdir(parents=True, exist_ok=True)
    formula_roots: set[Path] = set()
    for source in sources.values():
        parts = source.parts
        if "Cellar" not in parts:
            continue
        index = parts.index("Cellar")
        if len(parts) > index + 2:
            formula_roots.add(Path(*parts[:index + 3]))

    for formula_root in sorted(formula_roots):
        formula_name = formula_root.parent.name
        destination_dir = licenses_root / formula_name
        candidates: set[Path] = set()
        for pattern in ("LICENSE*", "COPYING*", "Copyright*", "copyright*"):
            candidates.update(path for path in formula_root.glob(pattern) if path.is_file())
            candidates.update(path for path in formula_root.glob(f"share/doc/*/{pattern}") if path.is_file())
        if not candidates:
            continue
        destination_dir.mkdir(parents=True, exist_ok=True)
        used_names: set[str] = set()
        for source_license in sorted(candidates):
            name = source_license.name
            if name in used_names:
                name = "-".join(source_license.relative_to(formula_root).parts)
            used_names.add(name)
            shutil.copy2(source_license, destination_dir / name)

    binaries = [executable, *(frameworks / name for name in sorted(sources))]
    bundled_names = set(sources)
    for binary in binaries:
        for reference in dependencies(binary):
            name = Path(reference).name
            if name in bundled_names:
                run("/usr/bin/install_name_tool", "-change", reference, f"@rpath/{name}", str(binary))

    for name in sorted(sources):
        run("/usr/bin/install_name_tool", "-id", f"@rpath/{name}", str(frameworks / name))

    app_rpath = "@executable_path/../Frameworks"
    existing_rpaths = rpaths(executable)
    if app_rpath not in existing_rpaths:
        run("/usr/bin/install_name_tool", "-add_rpath", app_rpath, str(executable))
    for path in existing_rpaths:
        if path.startswith("/opt/homebrew/"):
            run("/usr/bin/install_name_tool", "-delete_rpath", path, str(executable))

    unresolved: list[str] = []
    for binary in binaries:
        for reference in dependencies(binary):
            if reference.startswith("/opt/homebrew/"):
                unresolved.append(f"{binary.name}: {reference}")
            elif reference.startswith("@rpath/") and Path(reference).name not in bundled_names:
                unresolved.append(f"{binary.name}: {reference}")
    if unresolved:
        raise RuntimeError("unresolved bundled dependencies:\n" + "\n".join(unresolved))

    total_bytes = sum(path.stat().st_size for path in frameworks.glob("*.dylib"))
    print(
        f"Bundled {len(sources)} dynamic libraries "
        f"from {len(formula_roots)} Homebrew packages "
        f"({total_bytes / 1024 / 1024:.1f} MiB)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
