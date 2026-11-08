# Deploying leproc

Leproc will be a World of Warcraft addon: it runs inside the game client (WoW:
Forever), and there's no server. There's no addon code yet, so the steps below
work once `Leproc/Leproc.toc` exists.

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

1. Run the checks (none yet), commit and push.
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

None yet. TODO: the settings it needs (names only, never the values) and
where they live.

## Troubleshooting

TODO: logs, health checks, common problems.
