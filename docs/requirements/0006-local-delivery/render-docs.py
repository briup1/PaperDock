#!/usr/bin/env python3
"""Reuse the project's existing Markdown renderer without rewriting its sources."""
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parent
renderer = runpy.run_path(str(ROOT.parent / '0001-local-notes/render-docs.py'))
generate = renderer['generate']
generate.__globals__['ROOT'] = ROOT
generate('requirement.wl-req-confirm')
page = ROOT / 'requirement.wl-req-confirm.html'
# The older template links prototype evidence; this workflow has its own implementation record.
page.write_text(page.read_text().replace('../../prototype-validation.md', 'implementation.md'))
