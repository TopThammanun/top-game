---
id: generated-docs-are-machine-output
type: team_decision
title: "*.generated.md files are machine output — do not hand-edit"
domain: design-docs
tags: [generated, docs, pipeline]
status: proposed
enforcement: block
applies_to: [design-docs, "docs/**/*.generated.md"]
source: ai
related: [regenerate-after-asset-change]
timestamp: 2026-07-04T00:00:00Z
---

Any file matching `*.generated.md` (currently `docs/ASSET_INDEX.generated.md`)
is written by a script and MUST NOT be hand-edited.

If the generated file is wrong, fix the **generator**, not the output.
Currently: `tools/generate_asset_catalog.ps1` produces
`docs/ASSET_INDEX.generated.md`; edit the PowerShell, then re-run it.

Why "block": hand-edits get overwritten on the next generator run — the fix
looks correct in review, then silently disappears the next time someone
regenerates. It's a classic "why did my change vanish?" bug.
