# Deploying leproc

Leproc is a World of Warcraft addon: it runs inside the game client (WoW:
Forever, Interface 16001), and there's no server.

TODO: where will releases be published (CurseForge, Wago, GitHub Releases)?

## First-time setup

On the Windows test PC:

1. Clone the repo anywhere: `git clone https://github.com/addohm/leproc.git`
   (it needs your GitHub login if the repo is private).
2. Open `tools\install_forever.cmd` and check `WOW` at the top: it's the client
   folder, by default `C:\Program Files (x86)\World of Warcraft\_forever_`.
3. Run `tools\install_forever.cmd` from a terminal, then start the game. Check
   that Leproc is enabled under AddOns on the character-select screen.

To install by hand instead, copy the `Leproc` folder (not the repo root) into
`<WoW>\_forever_\Interface\AddOns\`.

## Shipping a change

1. Run the tests (`.venv/bin/python tests/run_tests.py`), commit and push.
2. On Windows, run `tools\install_forever.cmd`, then `/reload` (or restart the
   game if it says so).
3. For a release: bump `## Version` in `Leproc/Leproc.toc`, move the
   CHANGELOG's Unreleased entries under the new version, and commit. Then
   `python3 tools/make_release.py` writes `release/Leproc-<version>.zip` from the
   committed `Leproc/` folder (it refuses if `Leproc/` has uncommitted changes);
   commit the zip, tag (`git tag v1.0.0`) and push with `--tags`.

### The install script

`tools\install_forever.cmd` (copied from Leboof's) does, in order:

- `git pull --ff-only` (it only gets what's pushed, so push first). The pull can
  update the script itself, so it runs from a copy in `%TEMP%`.
- Mirrors `Leproc\` into `<WOW>\Interface\AddOns\Leproc` (`robocopy /MIR`),
  creating the folder on the first run. If `WOW` itself doesn't exist it stops.
- Writes the commit into the installed `Build.lua` (`ns.build`), so the addon
  can show which build is running. The addon needs a `Build.lua` in its `.toc`
  for this. "-dirty" means the copy included uncommitted changes.
- Packs `Leproc-<version>.zip` on the desktop: `git archive` of the committed
  `Leproc\` folder, without the build stamp.
- Says whether `/reload` is enough. WoW reads the addon's file list only when
  the game starts, so when the `.toc` changed you must restart the game.

If creating or copying fails, the WoW folder may need the script to run as
administrator.

### Rolling back

Install an older version: `git checkout <tag> -- Leproc` in the clone, copy it
over the installed folder, then `git checkout main -- Leproc` to return.

## Configuration

There are no secrets or environment settings. In-game settings are profiles,
saved in `WTF/Account/<account>/SavedVariables/Leproc.lua` with which profile
each character uses.

## Troubleshooting

- `/leproc help` shows the build installed. If it's old, the install didn't
  copy (check `WOW` in the script) or the game needs a restart.
- Nothing glows: `/leproc test` lights every tracked ability's buttons. If
  that shows nothing, the ability isn't on a bar you can see. `/leproc why
  <ability>` says why it isn't lit (window, cooldown, stance, buttons),
  `/leproc bars` what Leproc found on the bars, `/leproc macros` what it read
  from each macro, `/leproc log` every trigger and glow as it happens (and what
  the game says), to copy with `/leproc log show`. A bar addon that builds its buttons late is noticed for 30 s
  after entering the world; `/reload` scans again too.
- Lua errors: turn them on with `/console scriptErrors 1` and send the text.
