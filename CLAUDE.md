# CLAUDE.md

Orientation for Claude working on leproc. Read this first.

## What this is

No code yet: the repo (`addohm/leproc` on GitHub) holds only the standard docs.

TODO: what the project does, its main parts, and how they fit together.

## Layout

- `README.md`: what it is, setup and usage
- `CHANGELOG.md`: changes, newest first, under *Unreleased* until a release
- `DEPLOY.md`: how it's deployed and run live
- `SECURITY.md`: secrets, access, reporting problems
- `ROADMAP.md`: done, next, ideas
- `CLAUDE.md`: this file

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
