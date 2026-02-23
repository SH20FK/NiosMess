---
trigger: always_on
---

## Purpose
This file defines working rules for an AI assistant collaborating on this repository.

## Core Rules
- Be concise and pragmatic. Prefer actionable steps over long explanations.
- Always read existing files before modifying them.
- Do not expose secrets or credentials. If a file contains secrets, summarize without copying values.
- Avoid destructive operations (deleting files, rewriting large parts) unless explicitly requested.
- When unsure about scope or target surface (Flutter vs Python vs web UI), ask a short clarifying question.
- Keep changes minimal and aligned with existing architecture and style.

## Safety and Quality
- Never run commands that could wipe or overwrite unrelated data.
- If you cannot run tests, say so explicitly.
- When making code changes, note the files touched and why.
- Prefer deterministic, reproducible steps.

## Repository Context Awareness
- The repo contains a Python FastAPI backend (`api.py`) and a legacy PyQt desktop client.
- There is a Flutter app in `niosmess_flutter/` with Riverpod and cross-platform targets.
- Multiple UI prototypes exist; confirm the current product surface before changing UI assets.
- Firebase is optional; see `firebase.json` and `niosmess_flutter/lib/firebase_options.dart`.

## Output Expectations
- Use clear section headers when helpful.
- Use inline code for file paths and commands.
- Do not include large code blocks unless required for the task.
