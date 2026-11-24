# Upstream sync record

One section per sync, newest last. This file is the durable store for what each upstream range
changed and how conflicts were resolved: `git rerere`'s cache is local-only and uncommitted.
Procedure and rules: `FORK.md` §3.

## 0. Status

| | |
|---|---|
| upstream | `termux/termux-app`, branch `master` |
| working branch | `develop` |
| syncs completed | 0 |
| behind upstream | 0 (forked at `8629e63`, 2026-09-26) |

## Cadence

Sync on **structural change**, not on a calendar. The tripwire (`just upstream-tripwire`, weekly in
`.github/workflows/upstream-tripwire.yml`) decides. Hard ceiling: never skip a second upstream
minor release. The rift fork learned this by absorbing 132 commits and four subsystem rewrites in a
single pass after a rule that existed only as prose went unenforced.

## Report template (copy for each sync)

```
## N. Nth sync: YYYY-MM-DD, <old tip> -> <new tip> (<k> commits)

behind upstream   <k>   ahead <m>  ->  after merge: 0 / <m>
merge commit      <sha> on develop

| Commit | Subject | Verdict (TAKE / TAKE+REWORK / SUPERSEDES-OURS) | What it changes in behaviour or cost |

Conflicts: each hunk, which side won, and why.
Consequences on our side: code or docs changed as a result.
Gates: ./gradlew test; CI assembleDebug.
Still unverified: on-device behaviour (see FORK.md §6 checklist).
```

## 1. Fork point: 2026-11-24

Forked from `upstream/master` `8629e63` ("Update `dependency-submission` to `v6`"). `develop` adds
`feat: horizontal swipe writes a configurable key sequence` (FORK.md §2.A) and the fork
maintenance tooling. Nothing merged yet.

Still unverified: everything on-device. The code was written without an Android SDK or JDK and has
not been compiled; the first compile and test run happens in `.github/workflows/fork-build.yml`.
