# CLAUDE.md

Orientation for Claude working on leproc. Read this first.

## What this is

A WoW: Forever addon for usable abilities, in the same style as Leboof. No
addon code yet. `ProcGlow/` (by Troy) is the user's design example: read it for
ideas, don't copy its code. It's git-ignored; never commit it.

TODO: what the project does, its main parts, and how they fit together.

## Layout

- `README.md`: what it is, setup and usage
- `CHANGELOG.md`: changes, newest first, under *Unreleased* until a release
- `DEPLOY.md`: how it's deployed and run live
- `SECURITY.md`: secrets, access, reporting problems
- `ROADMAP.md`: done, next, ideas
- `CLAUDE.md`: this file
- `ProcGlow/`: someone else's addon, a design example only (git-ignored, local)
- `tools/install_forever.cmd`: Windows; pulls, mirrors `Leproc/` into the
  client, stamps `Build.lua`, packs a zip on the desktop (CRLF, see
  `.gitattributes`)
- `tools/make_release.py`: builds `release/Leproc-<version>.zip` from the
  committed `Leproc/` folder

Add the code's folders here as they appear.

## Workflow

1. Start from the latest: pull before changing anything.
2. Make the change with tests.
3. **Update the docs in the same commit.** Every change updates the docs it
   affects:
   - README.md: setup and usage
   - CHANGELOG.md: an entry under *Unreleased*
   - DEPLOY.md: when deploying or running it live changes
   - SECURITY.md: when secrets, access or permissions change
   - ROADMAP.md: when something on it is done, or new plans are made
   - this file: when the layout, workflow or conventions change
4. Run the checks, then commit. There are none yet (no code). TODO: the lint
   and test commands, once chosen.

## Conventions

TODO: coding style, naming, anything a newcomer would get wrong (none set
yet; language and tooling still to be chosen).

## Don't

- Commit secrets (`.env`, keys, tokens).
