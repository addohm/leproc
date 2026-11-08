# Security

## Reporting a problem

TODO: who to tell, and how. Please don't open a public issue for a
vulnerability.

## Secrets

None. Leproc is an addon with no servers or keys. Its settings are saved by the
game in `WTF/Account/<account>/SavedVariables/Leproc.lua`. Never commit
secrets.

## Access

- The code lives at `addohm/leproc` on GitHub.
- The Claude workspace pushes over SSH through its own host alias
  (`deploy-ws-leproc`), not a personal key.
- Nothing runs on a server: players install the addon themselves.

TODO: who else can push or deploy, and how is that granted?
