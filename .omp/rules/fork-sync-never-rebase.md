---
description: "Upstream syncs are merges, never rebases: a rebase re-resolves every fork conflict once per upstream commit"
# `git\s+rebase` was too tight in the rift fork: `git -C <dir> rebase upstream/master`
# slipped through, and scratch worktrees are exactly where a sync gets experimented on.
condition: "\\bgit\\b[^\\n;&|]{0,40}\\brebase\\b[^\\n;&|]{0,80}\\bupstream\\b"
scope: "tool:bash"
interruptMode: tool-only
probes:
  fire:
    - "git rebase upstream/master"
    - "git rebase --onto upstream/master HEAD~3"
    - "git -C /tmp/probe rebase upstream/master"
    # A `-c` prefixed rebase is still a rebase.
    - "git -c rerere.enabled=false rebase upstream/master"
  silent:
    - "git merge upstream/master"
    - "just sync"
    - "just sync-to upstream/master"
    # Rebasing our own local commits is unrelated to absorbing upstream.
    - "git rebase -i HEAD~3"
---

# Sync with a merge, not a rebase

A rebase replays every commit this fork carries against every upstream step, so the same
conflict is resolved once per upstream commit. A merge resolves it once, and `rerere`
records it. The fork carries few commits today, but the rule is cheaper to keep than to
rediscover (rift fork, `FORK.md` §3: measured 2 conflicted files for a range merge versus 7
for commit-by-commit on the same range).

```bash
# WRONG
git rebase upstream/master

# RIGHT: merges the range, gated on the unit tests.
just sync
```

Too large for one bite? `just sync-to <ref>`: a smaller range, still a range.

## Rebase is for upstreaming only

A clean linear PR against `termux/termux-app` is the one place it earns its cost, and that
happens on a dedicated feature branch, never on `develop`.
