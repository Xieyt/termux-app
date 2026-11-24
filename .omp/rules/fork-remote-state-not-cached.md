---
description: "`origin/<branch>` is a local cache; confirm with `ls-remote` before reporting push state"
condition: "rev-list[^\\n]{0,60}\\borigin\\b"
scope: "tool:bash"
interruptMode: tool-only
probes:
  fire:
    - "git rev-list --count origin/develop..HEAD"
    - "git rev-list --left-right --count origin/develop...HEAD"
  silent:
    # upstream/master is refreshed by the `git fetch upstream` the recipes run.
    - "git rev-list --count HEAD..upstream/master"
    - "git rev-list --reverse --no-merges HEAD..upstream/master"
---

# `origin/<branch>` is a cache, not the remote

`git rev-list --count origin/develop..HEAD` reads the **local remote-tracking ref**. That ref
only moves on `git fetch origin` or `git push`; `git fetch upstream` does not refresh it.

## Confirm before reporting

```bash
# Authoritative: asks the remote.
git ls-remote origin refs/heads/develop | cut -f1
git rev-parse HEAD

# Or refresh the cache first; then the cached ref is trustworthy.
git fetch origin --quiet && git rev-list --count origin/develop..HEAD
```

## `origin/HEAD` is the same trap

Nothing refreshes a symref except `git remote set-head origin -a`. Ask the remote:

```bash
git ls-remote --symref origin HEAD
```

This fork's default branch is `develop`, and there is no mirror branch: read `upstream/master`
directly (`FORK.md` §1). When a check disagrees with the code, suspect the probe first and name
the instrument when you report the result (the rift fork's sixth instance of this pattern).
