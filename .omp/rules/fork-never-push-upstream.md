---
description: "This fork never pushes to `upstream` (`termux/termux-app`): `origin` only"
# Gaps exclude `;`, `&`, `|` so a compound command cannot bridge an innocent
# `git push origin ...` into an unrelated `... upstream` clause and burn the rule
# (repeatMode is `once`). `\bgit\b[^...]{0,40}\bpush\b` tolerates `-C <dir>` / `-c k=v`.
condition: "\\bgit\\b[^\\n;&|]{0,40}\\bpush\\b[^\\n;&|]{0,80}\\bupstream\\b"
scope: "tool:bash"
interruptMode: tool-only
probes:
  fire:
    - "git push upstream develop"
    - "git push --force-with-lease upstream master"
    # Pushing *to* origin but writing an upstream ref is the same mistake.
    - "git push origin upstream/master:master"
    - "git -C /tmp/probe push upstream master"
  silent:
    - "git push origin develop"
    - "git fetch upstream --quiet"
    # `upstream/master` as a read source is fine; only `push` is the violation.
    - "git merge upstream/master"
    - "git rev-list --count HEAD..upstream/master"
    # A compound whose push targets origin and whose *other* clause reads upstream.
    - "git push origin develop && git fetch upstream --quiet"
---

# Never push to `upstream`

`upstream` is `termux/termux-app`, a repository we do not own. `FORK.md` §1 states the
rule as absolute: local work never touches upstream; we only ever push to `origin`
(`Xieyt/termux-app`).

```bash
# WRONG: pushes the fork's work into someone else's repository.
git push upstream develop

# RIGHT: our fork, our branch.
git push origin develop
```

## The one exception, and it is not this

Contributing back is a PR **from a dedicated feature branch on `origin`**, never a push
to `upstream`. The swipe feature is not a candidate as written: upstream's maintainers
decide what the terminal view does with gestures.

If the intent was to *read* upstream, the verb is `fetch`, not `push`.
