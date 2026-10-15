from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import yaml
import pytest


ROOT = Path(__file__).resolve().parents[1]


def template_checkout(path: Path) -> Path:
    source = path / "template-source"
    shutil.copytree(ROOT, source, ignore=shutil.ignore_patterns(".git", ".quarto", "_manuscript", "__pycache__", ".pytest_cache"))
    env = {**os.environ, "GIT_CONFIG_COUNT": "2", "GIT_CONFIG_KEY_0": "user.name", "GIT_CONFIG_VALUE_0": "Template Test", "GIT_CONFIG_KEY_1": "user.email", "GIT_CONFIG_VALUE_1": "test@example.invalid"}
    subprocess.run(["git", "init", "-b", "main"], cwd=source, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=source, check=True, env=env)
    subprocess.run(["git", "commit", "-m", "Template baseline"], cwd=source, check=True, env=env, capture_output=True)
    return source


@pytest.mark.integration
def test_copy_and_update(tmp_path: Path) -> None:
    destination = tmp_path / "sample-paper"
    source = template_checkout(tmp_path)
    subprocess.run(
        [
            "copier",
            "copy",
            "--defaults",
            "--trust",
            str(source),
            str(destination),
            "--data",
            "project_name=Sample project",
            "--data",
            "paper_title=A custom paper title",
            "--data",
            "authors=Alice Author, Bob Writer",
        ],
        check=True,
        env={**os.environ, "GIT_CONFIG_COUNT": "2", "GIT_CONFIG_KEY_0": "user.name", "GIT_CONFIG_VALUE_0": "Template Test", "GIT_CONFIG_KEY_1": "user.email", "GIT_CONFIG_VALUE_1": "test@example.invalid"},
    )

    paper = (destination / "paper.qmd").read_text()
    assert 'title: "A custom paper title"' in paper
    assert 'name: "Alice Author"' in paper
    assert 'name: "Bob Writer"' in paper
    assert yaml.safe_load((destination / ".copier-answers.yml").read_text())["project_name"] == "Sample project"
    expected = ["_quarto.yml", "_quarto-working.yml", "_quarto-preprint.yml", "paper.qmd", "references.bib", "Makefile", "csl/apa.csl", "template/main.tex", "filters/git-meta.lua", "metadata/preprint.yaml"]
    assert all((destination / path).is_file() for path in expected)
    forbidden = ["copier.yml", "copier-template", "tests", "pyproject.toml"]
    assert not any((destination / path).exists() for path in forbidden)

    original_bibliography = (destination / "references.bib").read_text()
    authored_manuscript = paper + "\nUser-authored content.\n"
    (destination / "paper.qmd").write_text(authored_manuscript)
    (destination / "references.bib").write_text(original_bibliography + "\n% user entry\n")
    subprocess.run(["git", "add", "paper.qmd", "references.bib"], cwd=destination, check=True)
    subprocess.run(["git", "commit", "-m", "Edit manuscript"], cwd=destination, check=True, capture_output=True)
    makefile = source / "copier-template" / "Makefile"
    makefile.write_text(makefile.read_text() + "\n# Copier update test\n")
    subprocess.run(["git", "add", "copier-template/Makefile"], cwd=source, check=True)
    subprocess.run(["git", "commit", "-m", "Update reusable infrastructure"], cwd=source, check=True, capture_output=True)
    subprocess.run(["copier", "update", "--trust", "--defaults"], cwd=destination, check=True)
    assert (destination / "paper.qmd").read_text() == authored_manuscript
    assert (destination / "references.bib").read_text().endswith("% user entry\n")
    assert "# Copier update test" in (destination / "Makefile").read_text()


@pytest.mark.integration
@pytest.mark.parametrize("command", [["quarto", "render", "paper.qmd", "--to", fmt] for fmt in ("html", "docx", "pdf")] + [["quarto", "render", "paper.qmd", "--to", "pdf", "--profile", profile, "--metadata-file", f"metadata/{profile}.yaml"] for profile in ("working", "preprint")])
def test_render_formats_and_profiles(tmp_path: Path, command: list[str]) -> None:
    destination = tmp_path / "render-paper"
    source = template_checkout(tmp_path)
    subprocess.run(["copier", "copy", "--defaults", "--trust", str(source), str(destination)], check=True, capture_output=True)
    subprocess.run(command, cwd=destination, check=True, capture_output=True)
