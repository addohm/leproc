# Security

## Reporting a problem

TODO: who to tell, and how. Please don't open a public issue for a
vulnerability.

## Secrets

None yet: there's no code or config. TODO: which secrets leproc uses, where
each one lives, and how to rotate it, once it has any. Never commit them.

## Access

- The code lives at `addohm/leproc` on GitHub.
- The Claude workspace pushes over SSH through its own host alias
  (`deploy-ws-leproc`), not a personal key.
- Nothing runs in production yet.

TODO: who else can push or deploy, and how is that granted?
